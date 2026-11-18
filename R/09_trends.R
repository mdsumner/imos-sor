# Monthly SST anomalies, trends and status from the in-situ daily sums of the
# IMOS L3S record (BoM/IMOS ABOM GHRSST L3S 1-day day+night, and the AVHRR
# night-only skin SST as single_night when it has been converted; 0.02 deg; not
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
# multi-sensor 2013-2022 (>= 7 of 10), single_night as single-sensor; all
# BoM fv02. Single-sensor coverage collapses after 2012 in parts of the
# south (west of ~90 E, and the Southern file outside the overlap), so a
# 2013-2022 base would drop those cells' whole record (HIMI among them).
# Trends don't depend on the base; compare products' anomalies after
# re-centring on common years.
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
# 2013-2024 (every product). The fv02 -> fv01 seam at 2023-01-01 is inside
# the last two; its size on paired pixels in 2022 (fv01 - fv02, from
# nci/offset_by_year.csv: the domain, eez_legal and star sets only) is joined
# for comparison. It was measured for day+night only, so single_night has
# none. single_night has no Southern file: its "whole domain" is the
# Continental window. Per-cell trends too (q4), for maps and local maxima.
# Status: each region's 2024 anomaly and its rank among the years.
#
# Regions whose area is mostly in cells south of 60 S are marked ice_zone:
# the ice screen in the sums is not consistent through time
# (notes/issues.md 20-21), so trends there are not to be read yet.
#
# Inputs: data/sums_imos/{s2l5,regions}/<product>_<variant>/<date>.parquet,
# data/mapping/union_s2l5.rds (R/06), data/coverage/<set>.parquet (R/03),
# boundaries/lattice.csv, boundaries/regions.csv, nci/offset_by_year.csv;
# settings and functions in R/trend_fns.R (shared with R/10_fine_trends.R).
# Writes data/trends/{cell,region}_monthly.parquet and, committed,
# trends/region_trends.csv, trends/cell_trends_q4.csv, trends/region_status.csv,
# trends/region_monthly_q4.csv.gz (STAR, EEZ and the domain, q4 only).
#
# usage (from the repo root): Rscript R/09_trends.R   (about 3 minutes, 16 cores)
suppressPackageStartupMessages({ library(data.table); library(parallel) })
CORES <- 16
src <- "data/sums_imos"
source("R/trend_fns.R")   # settings (base years, coverage rules, periods) and the fit
products <- c("single", "multi", "single_night"); variants <- c("all", "q4", "q4b")
products <- products[dir.exists(file.path(src, "s2l5", paste0(products, "_q4")))]   # single_night once converted
cat("products:", products, "\n")
dir.create("data/trends", showWarnings = FALSE); dir.create("trends", showWarnings = FALSE)

## ---- geometry: union lattice, the composite domain, pixel -> S2 L5 cell --------
lat <- read.csv("boundaries/lattice.csv"); u <- lat[lat$grid == "union", ]; NC <- u$ncol; NR <- u$nrow
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
read_kind <- function(kind, p, v) {
  f <- list.files(file.path(src, kind, paste0(p, "_", v)), full.names = TRUE, pattern = "parquet$")
  rbindlist(mclapply(f, function(x) as.data.table(nanoparquet::read_parquet(x)), mc.cores = CORES))
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
  ca <- anom_cell_regions(ov, cm)
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
long <- melt(regs_m[, .(product, variant, set, region_id, ym, year, direct = anom, cell = anom_cell)],
             measure.vars = c("direct", "cell"), variable.name = "method", value.name = "anom")
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
se_cells <- ov[set == "star" & region_id == 4L & w > 0.5 * cell_dkm2[cell] * ocean[cell], reg$cell[cell]]
for (p in intersect(c("single", "single_night"), products)) {
  cat("\nfastest-warming cells mostly in the South-east region,", p, "q4, 1993-2016:\n")
  print(head(ct[product == p & period == "1993-2016" & cell %in% se_cells][order(-slope)], 8), row.names = FALSE)
}
