# Crossover: the IMOS L3S record against two gap-free L4 analyses on the same
# S2 L5 cells, to tell which IMOS product drifts after 2017.
#
#   mur    GHRSST MUR v4.1 (JPL L4, 0.01 deg, foundation SST, 2002-06 ->):
#          trend.sst's `ghrsst` sums, made from the MUR v4.1 COGs at
#          source.coop/ausantarctic/ghrsst-mur-v2. Copied from the public
#          bucket pawsey1197:aad-derived/trend-sst/sums/ghrsst/ to
#          data/trend/ghrsst/. Known-bad MUR days 2025-08-24..29 are left out.
#   oisst  NOAA OISST v2.1 (0.25 deg, 1981-09 ->): trend.sst's `oisst` sums,
#          ~/Git/trend.sst/sums/oisst/ (the same bucket has them).
# Against R/09's three IMOS products (BoM/IMOS ABOM GHRSST L3S 1-day, 0.02
# deg; not MUR): single, multi and single_night, q4 and q4b.
#
# L3S is clear-sky and L4 is gap-free, so a cell-day is compared only when the
# L3S product saw at least min_clear of the cell's ocean that day (ocean as in
# R/09: the most of the cell ever seen in one day). The difference is the L3S
# cell mean minus the L4 cell mean. Only cells wholly inside the Continental
# (aus) window are used: there every product is the Continental file, and L3S
# and L4 cover the same cell. Whatever doesn't change through time (skin vs
# foundation, the coastal footprint, the clear-sky bias at a given coverage)
# is a steady offset; a drift is a change in the difference.
# Cell-month: mean of the matched days (>= min_days). Anomalies first, as R/09:
# each cell's monthly difference less its own calendar-month mean over R/09's
# base years (within the years the pair overlaps), so a month with fewer valid
# cells doesn't move the result by which cells they are. Region-month: mean of
# the cells' anomalies weighted as R/09 (the region's km2 in the cell, capped
# at the cell's ocean area), needing valid cells over xo_area_frac of the
# region's observable weight; looser than R/09 because single-sensor and night
# have few cell-days with enough clear sky. Year: mean of >= min_months valid
# months. The offset is the region's mean calendar-month difference. MUR -
# OISST on every day of the same cells checks the two references.
#
# Inputs: data/sums_imos/s2l5/<product>_<variant>/ (nci/sums_to_parquet.R),
# data/trend/{ghrsst}/, ~/Git/trend.sst/sums/oisst/, data/mapping/union_s2l5.rds,
# data/coverage/star.parquet, boundaries/lattice.csv, boundaries/regions.csv,
# trends/cell_trends_q4.csv (R/09's ocean share).
# Writes data/trends/crossover_cell_monthly.parquet and, committed,
# trends/crossover_annual.csv and trends/crossover_steps.csv.
#
# usage (from the repo root): Rscript R/11_crossover.R   (about 1.5 minutes, 16 cores)
suppressPackageStartupMessages({ library(data.table); library(parallel) })
CORES <- 16
source("R/trend_fns.R")   # cell_km2, ym_of, base, clim_anom, anom_cell_regions, fit
clear_cuts <- c(0.5, 0.8)  # a cell-day needs this share of the cell's ocean seen; the first is the main result
min_days <- 3              # matched days in a cell-month
xo_area_frac <- 0.25       # region-month: valid cells over this share of the observable weight
min_months <- 6            # valid months in a year
early <- 2012:2016; late <- 2019:2024   # as in notes/trends.md's night step
mur_bad <- seq(as.Date("2025-08-24"), as.Date("2025-08-29"), by = "day")
products <- c("single", "multi", "single_night"); variants <- c("q4", "q4b")
src <- "data/sums_imos/s2l5"
l4_dir <- c(mur = "data/trend/ghrsst", oisst = path.expand("~/Git/trend.sst/sums/oisst"))
stopifnot(dir.exists(l4_dir))

## ---- cells wholly in the aus window, their pixels, ocean share and region weights ----
lat <- read.csv("boundaries/lattice.csv"); u <- lat[lat$grid == "union", ]; NC <- u$ncol; NR <- u$nrow
rowarea <- cell_km2(NR, u$ymax, 0.02)
aw <- lat[lat$grid == "aus", ]
aus <- rep(FALSE, NC * NR)
aus[as.vector(outer(aw$col_offset + seq_len(aw$ncol), (aw$row_offset + seq_len(aw$nrow) - 1) * NC, "+"))] <- TRUE
map <- readRDS("data/mapping/union_s2l5.rds")
reg <- as.data.table(nanoparquet::read_parquet(map$registry))
s2i <- as.vector(t(map$idx))
npix <- tabulate(s2i[aus], nbins = nrow(reg))
tmp <- rowsum(rep(rowarea, each = NC)[aus], s2i[aus]); km2 <- numeric(nrow(reg)); km2[as.integer(rownames(tmp))] <- tmp[, 1]; rm(tmp)
## a cell is whole if the window holds (nearly) all of its area; WGS84 pixel areas against the
## spherical S2 cell area differ by a few tenths of a percent, so the cut is at 0.98
s2_km2 <- s2::s2_cell_area(s2::as_s2_cell(reg$cell)) / 1e6
whole <- km2 / s2_km2 > 0.98
oc <- fread("trends/cell_trends_q4.csv")[, .(ocean = max(ocean)), by = cell]
reg[, `:=`(i = .I, npix = npix, km2 = km2, whole = whole)]
reg <- merge(reg, oc, by = "cell", all.x = TRUE)[order(i)]
cells <- reg[whole & is.finite(ocean) & ocean > 0]
cat(sprintf("cells in the aus window: %d with any pixel, %d whole (share > 0.98), %d of them with an ocean share\n",
            sum(npix > 0), sum(whole), nrow(cells)))
cat("window share of the cells kept: min", round(min(cells$km2 / s2_km2[cells$i]), 4), "\n")

regions <- as.data.table(read.csv("boundaries/regions.csv"))[set == "star" & region_id <= 6]
tb <- nanoparquet::read_parquet("data/coverage/star.parquet")
len <- tb$col_end - tb$col_start + 1L; rr <- rep(tb$row, len)
pix <- sequence(len, from = tb$col_start) + (rr - 1L) * NC
ov <- data.table(region_id = rep(tb$region_id, len), i = s2i[pix], km2r = rep(tb$fraction, len) * rowarea[rr])[region_id <= 6]
ov <- ov[, .(km2r = sum(km2r)), by = .(region_id, i)]
lost <- ov[!i %in% cells$i, .(km2 = sum(km2r)), by = region_id]
ov <- merge(ov, cells[, .(i, cell, km2, ocean)], by = "i")
ov <- rbind(ov[, .(region_id, cell, w = pmin(km2r, km2 * ocean))],
            cells[, .(region_id = 0L, cell, w = km2 * ocean)])     # 0: every whole cell in the window
ov <- ov[w > 0]
names_ <- rbind(regions[, .(region_id, region)], data.table(region_id = 0L, region = "aus window (whole cells)"))
cat("STAR area outside the whole cells (km2):", paste(sprintf("%d %.0f", lost$region_id, lost$km2), collapse = ", "), "\n")

## ---- daily cell means ----------------------------------------------------------------
rd <- function(f, keep) rbindlist(mclapply(f, function(x) {
  d <- as.data.table(nanoparquet::read_parquet(x))[cell %chin% keep]
  d[, .(cell, date = as.Date(date), n, mean = sumwx / sumw)]
}, mc.cores = CORES))
l4 <- lapply(l4_dir, function(dd) {
  f <- list.files(dd, pattern = "parquet$", full.names = TRUE)
  f <- f[as.Date(sub("\\.parquet$", "", basename(f))) >= as.Date("1992-03-01")]
  rd(f, cells$cell)[, .(cell, date, l4 = mean)]
})
l4$mur <- l4$mur[!date %in% mur_bad]
for (r in names(l4)) { setkey(l4[[r]], cell, date)
  cat(sprintf("%s: %d days, %s .. %s, %d cells\n", r, uniqueN(l4[[r]]$date), min(l4[[r]]$date), max(l4[[r]]$date), uniqueN(l4[[r]]$cell))) }

## ---- L3S - L4 per cell-day, then cell-months ------------------------------------------
cm <- list()
for (p in products) for (v in variants) {
  t0 <- Sys.time()
  f <- list.files(file.path(src, paste0(p, "_", v)), pattern = "parquet$", full.names = TRUE)
  s <- rd(f, cells$cell)
  s <- merge(s, cells[, .(cell, cap = npix * ocean)], by = "cell")[, clear := n / cap][, cap := NULL]
  setkey(s, cell, date)
  for (r in names(l4)) for (mc in clear_cuts) {
    x <- l4[[r]][s[clear >= mc], nomatch = NULL][, d := mean - l4]
    x <- x[, .(d = mean(d), days = .N, clear = mean(clear)), by = .(cell, ym = ym_of(date))][days >= min_days]
    cm[[length(cm) + 1L]] <- x[, `:=`(product = p, variant = v, ref = r, min_clear = mc)]
  }
  cat(sprintf("%s %s: %d cell-days, %.0f%% at clear >= %.1f; %.0f s\n", p, v, nrow(s), 100 * mean(s$clear >= clear_cuts[1]),
              clear_cuts[1], as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  rm(s)
}
## the references against each other, every day
mur <- l4$mur; oisst <- l4$oisst   # (l4 is also a column name)
x <- mur[oisst, nomatch = NULL][, d := l4 - i.l4]; rm(mur, oisst)
cm[[length(cm) + 1L]] <- x[, .(d = mean(d), days = .N, clear = 1), by = .(cell, ym = ym_of(date))][
  , `:=`(product = "mur", variant = "-", ref = "oisst", min_clear = 0)]
cm <- rbindlist(cm, use.names = TRUE)
nanoparquet::write_parquet(as.data.frame(cm), "data/trends/crossover_cell_monthly.parquet")

## ---- anomalies first, then regions -------------------------------------------------
key <- c("product", "variant", "ref", "min_clear")
cm[, `:=`(mean = d, ok = TRUE)]
cm <- rbindlist(lapply(split(cm, by = key), function(x) clim_anom(x, "cell", if (x$product[1] %in% names(base)) x$product[1] else "single")))
nanoparquet::write_parquet(as.data.frame(cm[, c(key, "cell", "ym", "days", "clear", "d", "clim", "anom"), with = FALSE]),
                           "data/trends/crossover_cell_monthly.parquet")
min_area_frac <- xo_area_frac   # anom_cell_regions() reads it
ov2 <- ov[, .(set = "star", region_id, cell, w)]
ra <- rbindlist(lapply(split(cm, by = key), function(x) {
  ca <- anom_cell_regions(ov2, x[, .(cell, ym, mon, clim, anom)])
  ca[, (key) := x[1, key, with = FALSE]]
}))
## offset: the region's mean calendar-month difference (cells' climatologies, weighted)
off <- merge(unique(cm[is.finite(clim), c(key, "cell", "mon", "clim"), with = FALSE])[, .(clim = mean(clim)), by = c(key, "cell")], ov2, by = "cell", allow.cartesian = TRUE)[
  , .(offset = sum(w * clim) / sum(w)), by = c(key, "region_id")]
ra[, year := ym %/% 12L]
an <- ra[, .(d = if (sum(is.finite(anom_cell)) >= min_months) mean(anom_cell, na.rm = TRUE) else NA_real_, months = sum(is.finite(anom_cell))),
         by = c(key, "region_id", "year")]
an <- merge(an, names_, by = "region_id")
setorderv(an, c(key, "region_id", "year"))
fwrite(an[, c(key, "region_id", "region", "year", "months"), with = FALSE][, anom := round(an$d, 4)], "trends/crossover_annual.csv")

## steps: late - early (every year of each needs a value); drift 2003-2016 (and 1993-2016 against
## OISST): OLS on the monthly anomalies with R/09's AR(1)-inflated interval, per decade
pm <- function(d, y, yrs) if (all(yrs %in% y[is.finite(d)])) mean(d[y %in% yrs]) else NA_real_
st <- an[, .(early = pm(d, year, early), late = pm(d, year, late), sd_early = sd(d[year %in% early]),
             y2022 = d[year == 2022][1], y2023 = d[year == 2023][1]), by = c(key, "region_id", "region")]
st[, step := late - early]
dr <- rbindlist(lapply(list(c(2003, 2016), c(1993, 2016)), function(P) {
  months <- (P[1] * 12L):(P[2] * 12L + 11L)
  x <- ra[year >= P[1] & year <= P[2], c(key, "region_id", "ym", "anom_cell"), with = FALSE]
  x <- x[, .SD[match(months, ym)][, ym := months], by = c(key, "region_id")]
  f <- x[, as.list(fit(ym / 12 + 1 / 24, anom_cell)), by = c(key, "region_id")]
  f[n < min_period_frac * length(months), c("slope", "lo", "hi") := NA_real_]
  f[, .SD, .SDcols = c(key, "region_id", "slope", "lo", "hi")][, period := sprintf("%d_%d", P[1], P[2])]
}))
dr <- dcast(dr, as.formula(paste(paste(c(key, "region_id"), collapse = " + "), "~ period")), value.var = c("slope", "lo", "hi"))
st <- merge(merge(st, off, by = c(key, "region_id"), all.x = TRUE), dr, by = c(key, "region_id"), all.x = TRUE)
num <- setdiff(names(st), c(key, "region_id", "region")); st[, (num) := lapply(.SD, round, 3), .SDcols = num]
setcolorder(st, c(key, "region_id", "region", "offset", "early", "late", "step", "sd_early"))
setorderv(st, c("min_clear", "ref", "product", "variant", "region_id"))
fwrite(st, "trends/crossover_steps.csv")

## ---- print ----------------------------------------------------------------------------
wide <- function(x, val, by = c("product", "ref")) {
  x <- copy(x)[, col := do.call(paste, c(.SD, sep = "-")), .SDcols = by]
  print(dcast(x, region_id + region ~ col, value.var = val)[, region_id := NULL], row.names = FALSE)
}
main <- st[(variant == "q4" & min_clear == clear_cuts[1]) | product == "mur"]
cat(sprintf("\nstep, %d-%d less %d-%d (C), anomalies, q4, clear >= %.1f; MUR - OISST on every day:\n", min(late), max(late), min(early), max(early), clear_cuts[1]))
wide(main, "step")
cat("\noffset (L3S - L4, C):\n"); wide(main, "offset")
cat("\ndrift 2003-2016 (C/decade):\n"); wide(main, "slope_2003_2016")
cat("\ndrift 1993-2016 against OISST (C/decade):\n"); wide(main[ref == "oisst" & product != "mur"], "slope_1993_2016")
cat("\nstep at clear >= ", clear_cuts[2], ":\n", sep = ""); wide(st[variant == "q4" & min_clear == clear_cuts[2]], "step")
cat("\nstep, q4b (clear >= ", clear_cuts[1], "):\n", sep = ""); wide(st[variant == "q4b" & min_clear == clear_cuts[1]], "step")
cat("\nannual anomaly of the difference, aus window and South-east, q4, clear >= ", clear_cuts[1], " (C):\n", sep = "")
z <- an[((variant == "q4" & min_clear == clear_cuts[1]) | product == "mur") & region_id %in% c(0L, 4L) & year >= 2002]
z[, col := paste(product, ref, sep = "-")][, d := round(d, 2)]
print(dcast(z, region + year ~ col, value.var = "d"), row.names = FALSE)
