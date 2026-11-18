# Trends on finer S2 cells over one region's box, from the exact daily sums
# of nci/sums_fine.R (BoM/IMOS ABOM GHRSST L3S 1-day, 0.02 deg; not MUR).
# Default: the STAR South-east region's 45 S2 L5 cells, summed at S2 L8
# (about 33 km at 42 S) and rolled up the S2 tree to L7, L6 and L5.
#
# The method is R/09's (R/trend_fns.R): monthly sums per cell, a
# calendar-month climatology over each product's base years, the relative
# coverage rule, OLS with an AR(1)-inflated standard error, and anomalies
# first for the region. Daily sums are rolled up before the monthly step, so
# each level has its own pixel-days and largest daily count (the ocean
# share), as R/09 has at L5. L5 from the fine sums must reproduce R/09's L5
# cell trends and its South-east cell-method trends; that is checked here.
#
# Inputs: data/nci/sums-fine-se-l8/<product>/<YYYY-MM>.rds (copied back from
# Gadi), nci/fine_kit_star_4_l8.rds, data/coverage/star.parquet,
# boundaries/lattice.csv, and R/09's trends/ CSVs for the check.
# Writes data/trends/fine_se_cell_monthly.parquet and, committed,
# trends/fine_se_cell_trends_q4.csv (every level) and trends/fine_se_region_trends.csv.
#
# usage (from the repo root): Rscript R/10_fine_trends.R [sums dir] [kit]
suppressPackageStartupMessages({ library(data.table); library(parallel) })
CORES <- 16
a <- commandArgs(TRUE)
src <- if (length(a) >= 1) a[1] else "data/nci/sums-fine-se-l8"
kit_f <- if (length(a) >= 2) a[2] else "nci/fine_kit_star_4_l8.rds"
source("R/trend_fns.R")
B <- readRDS(kit_f)
stopifnot(identical(readRDS(file.path(src, "kit.rds")), B[c("set", "region_id", "level", "xoff", "yoff", "ncol", "nrow", "cell", "tokens")]))
scr <- readRDS(file.path(src, "screen.rds"))
products <- c("single", "multi", "single_night"); variants <- c("all", "q4", "q4b")
products <- products[dir.exists(file.path(src, products))]
levels <- B$level:5L
cat(sprintf("%s %d (%s): L%d sums in %d L5 cells; products: %s; screen: ice bit %d, SST %g .. %g C\n", B$set, B$region_id, B$region,
            B$level, length(B$l5), paste(products, collapse = " "), scr$ice_bit, scr$sst_min, scr$sst_max))
dir.create("data/trends", showWarnings = FALSE); dir.create("trends", showWarnings = FALSE)

## ---- geometry: the fine cells, their parents, pixels and areas -----------------
lat <- read.csv("boundaries/lattice.csv"); u <- lat[lat$grid == "union", ]
rowarea <- cell_km2(u$nrow, u$ymax, 0.02)
pix_km2 <- rep(rowarea[B$union_rows[1]:B$union_rows[2]], each = B$ncol)
inb <- B$cell > 0L
npix_f <- tabulate(B$cell[inb], nbins = length(B$tokens))
km2_f <- numeric(length(B$tokens)); tmp <- rowsum(pix_km2[inb], B$cell[inb]); km2_f[as.integer(rownames(tmp))] <- tmp[, 1]
## per level: token of each level cell, and the level index of each fine cell
fine_to <- lapply(setNames(levels, paste0("L", levels)), function(L) {   # level index of each fine cell
  tok <- if (L == B$level) B$tokens else as.character(s2::s2_cell_parent(s2::as_s2_cell(B$tokens), L))
  match(tok, sort(unique(tok)))
})
lv <- rbindlist(lapply(levels, function(L) {
  tok <- if (L == B$level) B$tokens else as.character(s2::s2_cell_parent(s2::as_s2_cell(B$tokens), L))
  cells <- sort(unique(tok)); idx <- fine_to[[paste0("L", L)]]
  ll <- s2::s2_cell_to_lnglat(s2::as_s2_cell(cells))
  data.table(level = L, cell = seq_along(cells), token = cells, lon = round(s2::s2_x(ll), 3), lat = round(s2::s2_y(ll), 3),
             npix = tabulate(rep(idx, npix_f), length(cells)), km2 = as.vector(tapply(km2_f, factor(idx, seq_along(cells)), sum)))
}))
lv[, lon := ifelse(lon < 0, lon + 360, lon)]
stopifnot(setequal(lv[level == 5L, token], B$l5))
cat("cells per level:", paste(lv[, .N, by = level][, sprintf("L%d %d", level, N)], collapse = ", "), "\n")
## the region's area in each fine cell (R/03's coverage fractions on the lattice)
cov <- nanoparquet::read_parquet(file.path("data/coverage", paste0(B$set, ".parquet")))
cov <- cov[cov$region_id == B$region_id & cov$row >= B$union_rows[1] & cov$row <= B$union_rows[2], ]
len <- cov$col_end - cov$col_start + 1L; rr <- rep(cov$row, len)
cc <- sequence(len, from = cov$col_start) - B$union_cols[1] + 1L
pb <- (rr - B$union_rows[1]) * B$ncol + cc
keep <- cc >= 1L & cc <= B$ncol
reg_f <- data.table(cell = B$cell[pb[keep]], km2 = rep(cov$fraction, len)[keep] * rowarea[rr[keep]])[cell > 0L, .(km2 = sum(km2)), by = cell]
cat(sprintf("region area in the box: %.0f km2 of %.0f km2 in its coverage table\n", sum(reg_f$km2), sum(rep(cov$fraction, len) * rowarea[rr])))

## ---- daily sums -> monthly, at every level ----------------------------------------
read_product <- function(p) {
  f <- list.files(file.path(src, p), pattern = "^[0-9]{4}-[0-9]{2}\\.rds$", full.names = TRUE)
  r <- mclapply(f, function(x) { b <- readRDS(x); good <- b$days$date[b$days$error == "" & !b$days$stale]
    list(s2 = as.data.table(b$s2)[date %in% good], days = b$days) }, mc.cores = CORES)
  list(s2 = rbindlist(lapply(r, `[[`, "s2")), days = rbindlist(lapply(r, `[[`, "days")))
}
cells_m <- list()
for (p in products) {
  t0 <- Sys.time(); d <- read_product(p)
  cat(sprintf("%s: %d days (%d failed, %d stale left out), %d cell-day rows; %.0f s\n", p, nrow(d$days), sum(d$days$error != ""),
              sum(d$days$stale & d$days$error == ""), nrow(d$s2), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  s <- d$s2; rm(d)
  s[, ym := ym_of(date)]
  for (v in variants) for (L in levels) {
    x <- s[variant == v, .(cell = fine_to[[paste0("L", L)]][cell], date, ym, n, sumw, sumwx, sumwx2)]
    if (L != B$level) x <- x[, .(n = sum(n), sumw = sum(sumw), sumwx = sum(sumwx), sumwx2 = sum(sumwx2)), by = .(cell, date, ym)]
    cm <- x[, .(n = sum(n), sumw = sum(sumw), sumwx = sum(sumwx), sumwx2 = sum(sumwx2), days = .N, nmax = max(n)), by = .(cell, ym)]
    np <- lv[level == L, npix]
    cm[, `:=`(mean = sumwx / sumw, cov = n / (np[cell] * days_in(ym)))]
    cm[, ok := n >= min_npix & cov >= rel_cov * median(cov), by = cell]
    cm <- clim_anom(cm, "cell", p)
    cm[, `:=`(product = p, variant = v, level = L)]
    cells_m[[paste(p, v, L)]] <- cm
  }
  rm(s); invisible(gc())
}
cells_m <- rbindlist(cells_m, use.names = TRUE)
## ocean share of each cell: the most of it ever seen in one day, over every product and variant (as R/09)
oc <- cells_m[, .(nmax = max(nmax)), by = .(level, cell)]
lv <- merge(lv, oc, by = c("level", "cell"), all.x = TRUE)
lv[, ocean := pmin(1, fifelse(is.na(nmax), 0, nmax / npix))][, nmax := NULL]
nanoparquet::write_parquet(as.data.frame(merge(cells_m, lv[, .(level, cell, token)], by = c("level", "cell"))[
  , .(product, variant, level, cell = token, ym, n, sumw, sumwx, sumwx2, days, mean, cov, clim, anom)]), "data/trends/fine_se_cell_monthly.parquet")

## ---- cell trends (q4) ----------------------------------------------------------------
## region share: the region's area in the cell over the cell's area
reg_l <- rbindlist(lapply(levels, function(L) reg_f[, .(km2_region = sum(km2)), by = .(cell = fine_to[[paste0("L", L)]][cell])][, level := L]))
lv <- merge(lv, reg_l, by = c("level", "cell"), all.x = TRUE)[is.na(km2_region), km2_region := 0]
ct <- trends_of(cells_m[variant == "q4", .(product, level, cell, ym, year, anom)], c("product", "level", "cell"))
ct <- merge(ct, lv, by = c("level", "cell"))
ct <- ct[is.finite(slope), .(product, level, cell = token, lon, lat, ocean = round(ocean, 3), region_share = round(km2_region / km2, 3), period,
                             slope = round(slope, 4), lo = round(lo, 4), hi = round(hi, 4), n, months_frac = round(months_frac, 3))]
setorder(ct, product, level, period, cell)
fwrite(ct, "trends/fine_se_cell_trends_q4.csv")

## ---- the region, anomalies first, at every level --------------------------------------
ov <- lv[km2_region > 0, .(set = B$set, region_id = B$region_id, level, cell, w = pmin(km2_region, km2 * ocean))][w > 0]
ra <- rbindlist(lapply(split(cells_m, by = c("product", "variant", "level")), function(cm) {
  ca <- anom_cell_regions(ov[level == cm$level[1], .(set, region_id, cell, w)], cm)
  ca[, `:=`(product = cm$product[1], variant = cm$variant[1], level = cm$level[1], year = ym %/% 12L)]
}))
rt <- trends_of(ra[, .(product, variant, level, ym, year, anom = anom_cell)], c("product", "variant", "level"))
rt <- rt[, .(product, variant, level, region = B$region, period, slope = round(slope, 4), lo = round(lo, 4), hi = round(hi, 4),
             se = round(se, 4), n, months_frac = round(months_frac, 4), r1 = round(r1, 4), n_eff = round(n_eff, 4))]
setorder(rt, product, variant, level, period)
fwrite(rt, "trends/fine_se_region_trends.csv")

## ---- checks against R/09 (L5) -------------------------------------------------------------
mx <- function(x) if (any(is.finite(x))) max(abs(x), na.rm = TRUE) else NA_real_
c9 <- fread("trends/cell_trends_q4.csv")[cell %in% B$l5 & product %in% products]
k <- merge(ct[level == 5L], c9, by = c("product", "cell", "period"), all = TRUE, suffixes = c("", ".r09"))
cat(sprintf("\ncheck, L5 cell trends vs R/09: %d vs %d cell-periods, max |slope diff| %.1e, max |lo diff| %.1e, ocean diff %.1e\n",
            sum(is.finite(k$slope)), sum(is.finite(k$slope.r09)), mx(k$slope - k$slope.r09),
            mx(k$lo - k$lo.r09), mx(k$ocean - k$ocean.r09)))
r9 <- fread("trends/region_trends.csv")[set == B$set & region_id == B$region_id & method == "cell" & product %in% products]
k <- merge(rt[level == 5L], r9, by = c("product", "variant", "period"), suffixes = c("", ".r09"))
cat(sprintf("check, %s cell-method trends at L5 vs R/09: %d rows, max |slope diff| %.1e, max |hi diff| %.1e\n",
            B$region, nrow(k), mx(k$slope - k$slope.r09), mx(k$hi - k$hi.r09)))

## ---- print ------------------------------------------------------------------------------
cat("\n", B$region, ", anomalies first, q4, by level (C/decade):\n", sep = "")
x <- rt[variant == "q4"]; x[, txt := ifelse(is.finite(slope), sprintf("%+.2f [%+.2f, %+.2f]", slope, lo, hi), "-")]
if (nrow(x)) print(dcast(x, product + period ~ paste0("L", level), value.var = "txt"), row.names = FALSE)
for (p in intersect(c("single_night", "single"), products)) for (L in levels) {
  y <- ct[product == p & level == L & period == "1993-2016" & region_share > 0.5]
  if (!nrow(y)) next
  cat(sprintf("\n%s q4 1993-2016, L%d cells mostly in the region: %d; slope quantiles 5/50/95%% %+.2f %+.2f %+.2f; max %+.2f; >= 0.5: %d, >= 0.8: %d\n",
              p, L, nrow(y), quantile(y$slope, 0.05), median(y$slope), quantile(y$slope, 0.95), max(y$slope), sum(y$slope >= 0.5), sum(y$slope >= 0.8)))
  print(head(y[order(-slope), .(cell, lon, lat, ocean, region_share, slope, lo, hi, months_frac)], 6), row.names = FALSE)
}
