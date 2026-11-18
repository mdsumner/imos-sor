# Monthly SST anomalies, trends and status from the in-situ daily sums of the
# IMOS L3S record (BoM/IMOS ABOM GHRSST L3S 1-day day+night, 0.02 deg; not
# MUR): nci/sums.R -> nci/sums_to_parquet.R -> data/sums_imos/.
#
# Everything starts from exact sums: daily sums add to monthly sums; a mean
# is sumwx / sumw. Two ways to a region's monthly anomaly:
#   cell    anomalies first: each S2 L5 cell's monthly mean minus its own
#           climatology for that calendar month, then the region's anomaly is
#           the mean of its cells' anomalies, weighted by the area of the
#           region in each cell (exact on the 0.02 deg lattice). A month's
#           cloud pattern then moves the region anomaly much less than it
#           moves the region mean. A cell's anomaly is for the whole cell
#           (inside the domain), not just the part in the region.
#   direct  the region's own monthly mean (sum of its daily sums) minus its
#           climatology. Exact for the region, but which part of it was
#           cloud-free changes the mean from month to month.
# Climatology: calendar-month means over each product's base years, each
# year weighted equally: single-sensor 1993-2022 (>= 15 of the 30 years),
# multi-sensor 2013-2022 (>= 7 of 10); all BoM fv02. Single-sensor coverage
# collapses after 2012 in parts of the south (west of ~90 E, and the
# Southern file outside the overlap), so a 2013-2022 base would drop those
# cells' whole record (HIMI among them). Trends don't depend on the base;
# compare the two products' anomalies after re-centring on common years.
# A month counts if its coverage is at least a fifth of that cell's (or
# region's) median, so cells and regions that are partly land, and the
# sparser early AVHRR years, aren't dropped by a fixed cutoff. In the cell
# method each cell is weighted by the area of the region in it, capped at the
# cell's ocean area (estimated as the most of it ever seen in one day), and a
# month needs valid anomalies over half the region's observable area (cells
# with a climatology for that calendar month).
#
# Trends: OLS on monthly anomalies, with the standard error inflated for
# lag-1 autocorrelation of the residuals (effective n = n (1 - r1) / (1 + r1)).
# Periods: 1993-2016 (STAR 1.2), 1993-2024 (single-sensor in full years),
# 2013-2024 (both products). The fv02 -> fv01 seam at 2023-01-01 is inside
# the last two; its size on paired pixels in 2022 (fv01 - fv02, from
# nci/offset_by_year.csv: the domain, eez_legal and star sets only) is joined
# for comparison. Per-cell trends too (q4), for maps and local maxima.
# Status: each region's 2024 anomaly and its rank among the years.
#
# Regions whose area is mostly in cells south of 60 S are marked ice_zone:
# the ice screen in the sums is not consistent through time
# (notes/issues.md 20-21), so trends there are not to be read yet.
#
# Inputs: data/sums_imos/{s2l5,regions}/<product>_<variant>/<date>.parquet,
# data/mapping/union_s2l5.rds (R/06), data/coverage/<set>.parquet (R/03),
# boundaries/lattice.csv, boundaries/regions.csv, nci/offset_by_year.csv.
# Writes data/trends/{cell,region}_monthly.parquet and, committed,
# trends/region_trends.csv, trends/cell_trends_q4.csv, trends/region_status.csv,
# trends/region_monthly_q4.csv.gz (STAR, EEZ and the domain, q4 only).
#
# usage (from the repo root): Rscript R/09_trends.R   (about 2 minutes, 16 cores)
suppressPackageStartupMessages({ library(data.table); library(parallel) })
CORES <- 16
src <- "data/sums_imos"
base <- list(single = 1993:2022, multi = 2013:2022)
min_clim_years <- list(single = 15, multi = 7)   # per calendar month
periods <- data.frame(period = c("1993-2016", "1993-2024", "2013-2024"), from = c(1993, 1993, 2013), to = c(2016, 2024, 2024))
products <- c("single", "multi"); variants <- c("all", "q4", "q4b")
rel_cov <- 0.2           # a cell- or region-month counts if its coverage is >= 20% of its own median
min_npix <- 30           # ... and (cells) it has >= 30 pixel-days
min_area_frac <- 0.5     # cell method: cells with a valid anomaly cover >= half the region's observable ocean
min_period_frac <- 0.8   # a trend needs >= 80% of the period's months
status_year <- 2024
dir.create("data/trends", showWarnings = FALSE); dir.create("trends", showWarnings = FALSE)

## ---- geometry: union lattice, the composite domain, pixel -> S2 L5 cell --------
lat <- read.csv("boundaries/lattice.csv"); u <- lat[lat$grid == "union", ]; NC <- u$ncol; NR <- u$nrow
cell_km2 <- function(nrow, ymax, res) {
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  (b^2 / 2) * (g(top) - g(top - res * pi / 180)) * (res * pi / 180) / 1e6
}
rowarea <- cell_km2(NR, u$ymax, 0.02)
win_pix <- function(g) { w <- lat[lat$grid == g, ]; as.vector(outer(w$col_offset + seq_len(w$ncol), (w$row_offset + seq_len(w$nrow) - 1) * NC, "+")) }
dom <- rep(FALSE, NC * NR); dom[win_pix("aus")] <- TRUE; dom[win_pix("so")] <- TRUE
map <- readRDS("data/mapping/union_s2l5.rds")
reg <- as.data.table(nanoparquet::read_parquet(map$registry))
s2i <- as.vector(t(map$idx))
cell_npix <- tabulate(s2i[dom], nbins = nrow(reg))                       # domain pixels per cell
tmp <- rowsum(rep(rowarea, each = NC)[dom], s2i[dom])                      # domain km2 per cell
cell_dkm2 <- numeric(nrow(reg)); cell_dkm2[as.integer(rownames(tmp))] <- tmp[, 1]; rm(tmp)

## exact area of each region in each cell, inside the domain
regions <- as.data.table(read.csv("boundaries/regions.csv"))
sets <- c("star", "eez", "eez_legal", "imcra", "amp")
ov <- rbindlist(lapply(sets, function(s) {
  tb <- nanoparquet::read_parquet(file.path("data/coverage", paste0(s, ".parquet")))
  len <- tb$col_end - tb$col_start + 1L; rr <- rep(tb$row, len)
  pix <- sequence(len, from = tb$col_start) + (rr - 1L) * NC
  x <- data.table(region_id = rep(tb$region_id, len), cell = s2i[pix], km2 = rep(tb$fraction, len) * rowarea[rr])[dom[pix]]
  x[, .(km2 = sum(km2)), by = .(region_id, cell)][, set := s]
}))
ov <- rbind(ov, data.table(region_id = 1L, cell = which(cell_dkm2 > 0), km2 = cell_dkm2[cell_dkm2 > 0], set = "domain"))
ice <- ov[, .(ice_zone = sum(km2[reg$lat[cell] < -60]) / sum(km2) > 0.5), by = .(set, region_id)]
cat("cell x region overlaps:", nrow(ov), " regions:", nrow(unique(ov[, .(set, region_id)])), "\n")

## ---- monthly sums ---------------------------------------------------------------
ym_of <- function(d) as.integer(format(d, "%Y")) * 12L + as.integer(format(d, "%m")) - 1L
days_in <- function(ym) { y <- ym %/% 12L; m <- ym %% 12L + 1L
  as.integer(as.Date(sprintf("%d-%02d-01", y + (m == 12L), m %% 12L + 1L)) - as.Date(sprintf("%d-%02d-01", y, m))) }
read_kind <- function(kind, p, v) {
  f <- list.files(file.path(src, kind, paste0(p, "_", v)), full.names = TRUE, pattern = "parquet$")
  rbindlist(mclapply(f, function(x) as.data.table(nanoparquet::read_parquet(x)), mc.cores = CORES))
}
clim_anom <- function(x, key, p) {   # x: key cols + ym + mean + ok; adds clim and anom
  x[, `:=`(year = ym %/% 12L, mon = ym %% 12L + 1L)]
  cl <- x[ok == TRUE & year %in% base[[p]], .(clim = mean(mean), clim_years = .N), by = c(key, "mon")][clim_years >= min_clim_years[[p]]]
  x <- merge(x, cl[, c(key, "mon", "clim"), with = FALSE], by = c(key, "mon"), all.x = TRUE)
  x[, anom := fifelse(ok, mean - clim, NA_real_)]
  x
}
## pass 1: monthly sums, means, climatologies and anomalies for cells and regions
cells_m <- list(); regs_m <- list()
for (p in products) for (v in variants) {
  t0 <- Sys.time(); k <- paste(p, v)
  s <- read_kind("s2l5", p, v)
  s[, ym := ym_of(date)]
  cm <- s[, .(n = sum(n), sumw = sum(sumw), sumwx = sum(sumwx), sumwx2 = sum(sumwx2), days = .N, nmax = max(n)), by = .(cell, ym)]
  rm(s)
  cm[, cell := match(cell, reg$cell)]
  cm[, `:=`(mean = sumwx / sumw, cov = n / (cell_npix[cell] * days_in(ym)))]
  cm[, ok := n >= min_npix & cov >= rel_cov * median(cov), by = cell]
  cm <- clim_anom(cm, "cell", p)
  cm[, `:=`(product = p, variant = v)]
  cells_m[[k]] <- cm
  r <- read_kind("regions", p, v)
  r[, ym := ym_of(date)]
  rm_ <- r[, .(n = sum(n), sumw = sum(sumw), sumwx = sum(sumwx), sumwx2 = sum(sumwx2), domain_km2 = domain_km2[1], days = .N), by = .(set, region_id, ym)]
  rm(r)
  rm_[, `:=`(mean = sumwx / sumw, cov = sumw / (domain_km2 * days_in(ym)))]
  rm_[, ok := is.finite(mean) & cov >= rel_cov * median(cov[is.finite(mean)]), by = .(set, region_id)]
  regs_m[[k]] <- clim_anom(rm_, c("set", "region_id"), p)
  cat(sprintf("%s %s: %d cell-months (%.0f%% valid), %d region-months (%.0f%% valid); %.0f s\n", p, v, nrow(cm), 100 * mean(cm$ok),
              nrow(rm_), 100 * mean(regs_m[[k]]$ok), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
## each cell's ocean share: the most of it ever seen in one day, over every product and variant
nm_ <- rbindlist(lapply(cells_m, function(x) x[, .(nmax = max(nmax)), by = cell]))[, .(nmax = max(nmax)), by = cell]
ocean <- numeric(nrow(reg)); ocean[nm_$cell] <- pmin(1, nm_$nmax / cell_npix[nm_$cell])
ov[, w := pmin(km2, cell_dkm2[cell] * ocean[cell])]
cat("ocean share: domain", round(sum(ov[set == "domain", w]) / sum(ov[set == "domain", km2]), 3),
    "; EEZ weights / areas", round(sum(ov[set == "eez", w]) / sum(ov[set == "eez", km2]), 4), "\n")
ov <- ov[w > 0]
## pass 2: anomalies first, then region means of them
for (k in names(cells_m)) {
  cm <- cells_m[[k]]
  a <- merge(ov, cm[is.finite(anom), .(cell, ym, anom)], by = "cell", allow.cartesian = TRUE)
  ca <- a[, .(anom_cell = sum(w * anom) / sum(w), w_valid = sum(w)), by = .(set, region_id, ym)]
  ob <- merge(ov, unique(cm[is.finite(clim), .(cell, mon)]), by = "cell", allow.cartesian = TRUE)[, .(w_obs = sum(w)), by = .(set, region_id, mon)]
  ca[, mon := ym %% 12L + 1L]
  ca <- merge(ca, ob, by = c("set", "region_id", "mon"))[, area_frac := w_valid / w_obs]
  ca[area_frac < min_area_frac, anom_cell := NA_real_]
  x <- merge(regs_m[[k]], ca[, .(set, region_id, ym, anom_cell, area_frac)], by = c("set", "region_id", "ym"), all = TRUE)
  x[, `:=`(product = cm$product[1], variant = cm$variant[1])]
  regs_m[[k]] <- x
}
cells_m <- rbindlist(cells_m, use.names = TRUE); regs_m <- rbindlist(regs_m, use.names = TRUE, fill = TRUE)
regs_m[, `:=`(year = ym %/% 12L, mon = ym %% 12L + 1L)]
nanoparquet::write_parquet(as.data.frame(cells_m[, .(product, variant, cell = reg$cell[cell], ym, n, sumw, sumwx, sumwx2, days, mean, cov, clim, anom)]),
                           "data/trends/cell_monthly.parquet")
nanoparquet::write_parquet(as.data.frame(regs_m[, .(product, variant, set, region_id, ym, n, sumw, sumwx, sumwx2, domain_km2, days, mean, cov, clim,
                                                    anom_direct = anom, anom_cell, area_frac)]), "data/trends/region_monthly.parquet")

## ---- trends -------------------------------------------------------------------------
fit <- function(t, y) {
  k <- is.finite(y); n <- as.numeric(sum(k))
  if (n < 24) return(c(n = n, slope = NA_real_, se = NA_real_, r1 = NA_real_, n_eff = NA_real_, lo = NA_real_, hi = NA_real_))
  m <- lm.fit(cbind(1, t[k]), y[k]); cf <- unname(m$coefficients); res <- y - (cf[1] + cf[2] * t)
  r1 <- { a <- res[-length(res)]; b <- res[-1]; j <- is.finite(a) & is.finite(b); if (sum(j) > 10) cor(a[j], b[j]) else NA }
  s2 <- sum(m$residuals^2) / (n - 2); se <- sqrt(s2 / sum((t[k] - mean(t[k]))^2))
  n_eff <- if (is.finite(r1) && r1 > 0) n * (1 - r1) / (1 + r1) else n
  se_a <- se * sqrt((n - 2) / max(n_eff - 2, 1)); q <- qt(0.975, max(n_eff - 2, 1))
  c(n = n, slope = cf[2] * 10, se = se_a * 10, r1 = as.numeric(r1), n_eff = n_eff, lo = (cf[2] - q * se_a) * 10, hi = (cf[2] + q * se_a) * 10)
}
long <- melt(regs_m[, .(product, variant, set, region_id, ym, year, direct = anom, cell = anom_cell)],
             measure.vars = c("direct", "cell"), variable.name = "method", value.name = "anom")
trends_of <- function(d, key) rbindlist(lapply(seq_len(nrow(periods)), function(i) {
  P <- periods[i, ]; months <- (P$from * 12L):(P$to * 12L + 11L)
  x <- d[year >= P$from & year <= P$to]
  x <- x[, .SD[match(months, ym)][, ym := months], by = key]   # complete monthly axis, gaps as NA
  f <- x[, as.list(fit(ym / 12 + 1 / 24, anom)), by = key]
  f[, `:=`(period = P$period, months_frac = n / length(months))]
  f[months_frac < min_period_frac, c("slope", "se", "lo", "hi") := NA_real_]
  f
}))
tr <- trends_of(long, c("product", "variant", "set", "region_id", "method"))
## the fv02 -> fv01 seam: fv01 - fv02 on paired pixels in 2022 (nci/offset.R); Continental window if it has the region
off <- as.data.table(read.csv("nci/offset_by_year.csv"))[as.character(year) == "2022" & is.finite(offset)]
off[, product2 := fifelse(grepl("avhrr", product), "single", "multi")][, win := sub("_.*", "", product)]
off <- off[order(product2, variant, set, region_id, win != "cont")][, .SD[1], by = .(product2, variant, set, region_id)]
tr <- merge(tr, off[, .(product = product2, variant, set, region_id, seam_2022 = round(offset, 4))], by = c("product", "variant", "set", "region_id"), all.x = TRUE)
nm <- rbind(regions[, .(set, region_id, region)], data.table(set = "domain", region_id = 1L, region = "whole domain"))
tr <- merge(merge(tr, nm, by = c("set", "region_id"), all.x = TRUE), ice, by = c("set", "region_id"), all.x = TRUE)
setcolorder(tr, c("product", "variant", "set", "region_id", "region", "method", "period", "slope", "lo", "hi", "se", "n", "months_frac", "r1", "n_eff", "seam_2022", "ice_zone"))
num <- c("slope", "lo", "hi", "se", "months_frac", "r1", "n_eff"); tr[, (num) := lapply(.SD, round, 4), .SDcols = num]
setorder(tr, product, variant, set, region_id, method, period)
fwrite(tr, "trends/region_trends.csv")
cq <- cells_m[variant == "q4", .(product, variant, cell, ym, year, anom)]
ct <- trends_of(cq, c("product", "variant", "cell"))
ct <- ct[, .(product, cell = reg$cell[cell], lon = round(reg$lon[cell], 2), lat = round(reg$lat[cell], 2), ocean = round(ocean[cell], 3), period,
             slope = round(slope, 4), lo = round(lo, 4), hi = round(hi, 4), n, months_frac = round(months_frac, 3))][is.finite(slope)]
setorder(ct, product, period, cell)
fwrite(ct, "trends/cell_trends_q4.csv")

## ---- status: the latest full year against the others --------------------------------
ann <- long[, .(anom = if (sum(is.finite(anom)) >= 10) mean(anom, na.rm = TRUE) else NA_real_), by = .(product, variant, set, region_id, method, year)]
st <- ann[is.finite(anom), .(years = .N, first = min(year), last = max(year),
                             anom_status = anom[year == status_year][1],
                             rank_warmest = if (any(year == status_year)) rank(-anom)[year == status_year][1] else NA_real_,
                             warmest_year = year[which.max(anom)], warmest_anom = max(anom)), by = .(product, variant, set, region_id, method)]
st <- merge(merge(st, nm, by = c("set", "region_id"), all.x = TRUE), ice, by = c("set", "region_id"), all.x = TRUE)
st[, `:=`(status_year = status_year, anom_status = round(anom_status, 3), warmest_anom = round(warmest_anom, 3))]
setcolorder(st, c("product", "variant", "set", "region_id", "region", "method", "status_year", "anom_status", "rank_warmest", "years", "first", "last", "warmest_year", "warmest_anom"))
setorder(st, product, variant, set, region_id, method)
fwrite(st, "trends/region_status.csv")
q4m <- regs_m[variant == "q4" & set %in% c("star", "eez", "domain"), .(product, set, region_id, year, month = mon, mean = round(mean, 4), cov = round(cov, 4),
                                                                  anom_direct = round(anom, 4), anom_cell = round(anom_cell, 4), area_frac = round(area_frac, 4))]
setorder(q4m, product, set, region_id, year, month)
fwrite(q4m, "trends/region_monthly_q4.csv.gz")

## ---- print the STAR regions ----------------------------------------------------------
show <- tr[set %in% c("star", "domain") & variant == "q4" & !(set == "star" & region_id > 6)]
print(dcast(show, region + product ~ method + period, value.var = "slope"), row.names = FALSE)
cat("\ncell-method 95% intervals, q4:\n")
print(show[method == "cell" & is.finite(slope), .(region, product, period, slope, lo, hi, n, r1 = round(r1, 2), seam_2022)], row.names = FALSE)
cat("\nfastest-warming cells mostly in the South-east region, single q4, 1993-2016:\n")
se_cells <- ov[set == "star" & region_id == 4L & w > 0.5 * cell_dkm2[cell] * ocean[cell], reg$cell[cell]]
print(head(ct[product == "single" & period == "1993-2016" & cell %in% se_cells][order(-slope)], 8), row.names = FALSE)
