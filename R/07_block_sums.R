# One 5-day block of IMOS L3S SST into exact sums: S2 L5 cells (trend.sst
# schema and conventions) and the region sets (coverage tables).
#
# Block: 2024-01-04 .. 2024-01-08 = time indices 4375..4379 of the Australia
# multi-sensor store, one whole time chunk. The same dates are read from the
# three other 1-day day+night L3S stores (wherever they sit in those stores'
# time axes, which are not all sorted).
#
# Products, each a composite on the union lattice: the Australia window
# where it exists, the Southern Ocean window elsewhere (so south of 70S,
# west of 70E and east of 190E come from the SO store).
#   multi  = L3SM  (multi sensor)  australia + southernocean stores
#   single = L3S   (AVHRR)         australia + southernocean stores
# Variants: all  = every finite SST as stored
#           q4   = quality_level >= 4
#           q4b  = quality_level >= 4, SST - sses_bias
# SST in degrees C (K - 273.15).
#
# Writes data/sums/s2l5/<product>_<variant>/<date>.parquet
#   (cell, date, n, sumw, sumwx, sumwx2; w = cos(lat): trend.sst's schema)
# and data/sums/regions/<product>_<variant>/<date>.parquet
#   (set, region_id, date, n, sumw, sumwx, sumwx2; w = cell km2 x coverage,
#    n = sum of coverage fractions; plus domain_km2 = region area inside the
#    product domain)
# and boundaries/overlap_check.csv: Australia vs SO stores where both exist.
#
# usage (from the repo root): Rscript R/07_block_sums.R
suppressPackageStartupMessages(library(gdalraster))
set_config_option("AWS_NO_SIGN_REQUEST", "YES"); set_config_option("AWS_REGION", "ap-southeast-2")
set_config_option("GDAL_NUM_THREADS", "ALL_CPUS"); set_config_option("GDAL_HTTP_MULTIPLEX", "YES")
set_config_option("CPL_LOG", "/dev/null")   # the multi-sensor store warns about its time dimension on every open

dates <- as.Date("2024-01-04") + 0:4
B <- "/vsis3/aodn-cloud-optimised/"
stores <- list(
  multi = c(aus = "satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_australia.zarr",
            so = "satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_southernocean.zarr"),
  single = c(aus = "satellite_ghrsst_l3s_1day_daynighttime_single_sensor_australia.zarr",
             so = "satellite_ghrsst_l3s_1day_daynighttime_single_sensor_southernocean.zarr"))
vars <- c("sea_surface_temperature", "quality_level", "sses_bias")

lat <- read.csv("boundaries/lattice.csv")
u <- lat[lat$grid == "union", ]; NC <- u$ncol; NR <- u$nrow; res <- 0.02
win_pix <- function(g) {   # union linear (lon-fastest) indices of a window, in the window's lon-fastest order
  w <- lat[lat$grid == g, ]
  as.vector(outer(w$col_offset + seq_len(w$ncol), (w$row_offset + seq_len(w$nrow) - 1) * NC, "+"))
}
pix <- list(aus = win_pix("aus"), so = win_pix("so"))
dom <- rep(FALSE, NC * NR); dom[pix$aus] <- TRUE; dom[pix$so] <- TRUE   # union domain mask

## S2 mapping (lon-fastest to match the read arrays)
map <- readRDS("data/mapping/union_s2l5.rds")
reg <- nanoparquet::read_parquet(map$registry)
s2i <- as.vector(t(map$idx)); s2w <- rep(map$w, each = NC)

## region pixel lists from the coverage tables
cell_km2 <- function(nrow, ymax, res) {
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  (b^2 / 2) * (g(top) - g(top - res * pi / 180)) * (res * pi / 180) / 1e6
}
rowarea <- cell_km2(NR, u$ymax, res)
sets <- c("eez_legal", "eez", "star", "imcra", "amp")
cov <- lapply(setNames(sets, sets), function(s) {
  tab <- nanoparquet::read_parquet(file.path("data/coverage", paste0(s, ".parquet")))
  len <- tab$col_end - tab$col_start + 1
  rr <- rep(tab$row, len)
  p <- data.frame(region_id = rep(tab$region_id, len),
                  pix = sequence(len, from = tab$col_start) + (rr - 1) * NC,
                  frac = rep(tab$fraction, len))
  p$w <- p$frac * rowarea[rr]
  p[dom[p$pix], ]   # only pixels inside the product domain
})
domain_km2 <- lapply(cov, function(p) tapply(p$w, p$region_id, sum))

## time axis -> index for each date (first occurrence; duplicates are reported)
time_index <- function(dsn) {
  t <- as.Date(as.POSIXct("1981-01-01", tz = "UTC") + as.numeric(mdim_read(dsn, "time")))
  i <- match(dates, t) - 1L
  if (anyNA(i)) stop("dates missing in ", dsn)
  dup <- sapply(dates, function(d) sum(t == d))
  if (any(dup > 1)) message("  duplicate time entries for ", paste(dates[dup > 1], collapse = " "))
  i
}
## read every requested date of one variable: one request per run of
## consecutive indices (chunks hold 5 time steps; reading day by day would
## fetch each chunk 5 times). Returns [lon, lat, date] (lon fastest).
read_block <- function(dsn, var, ti, g) {
  w <- lat[lat$grid == g, ]
  out <- array(NA_real_, c(w$ncol, w$nrow, length(ti)))
  runs <- split(seq_along(ti), cumsum(c(1, diff(ti) != 1)))
  for (r in runs) {
    out[, , r] <- mdim_read(dsn, var, start = c(ti[r[1]], 0, 0), count = c(length(r), w$nrow, w$ncol), as_array = TRUE)
  }
  out
}

sums_s2 <- function(x) {
  fin <- is.finite(x); x0 <- ifelse(fin, x, 0)
  s <- rowsum(cbind(as.double(fin), s2w * fin, s2w * x0, s2w * x0 * x0), s2i)
  keep <- s[, 1] > 0
  data.frame(cell = reg$cell[as.integer(rownames(s))[keep]], n = s[keep, 1], sumw = s[keep, 2],
             sumwx = s[keep, 3], sumwx2 = s[keep, 4])
}
sums_reg <- function(x) {
  do.call(rbind, lapply(sets, function(s) {
    p <- cov[[s]]; v <- x[p$pix]; fin <- is.finite(v); v0 <- ifelse(fin, v, 0)
    a <- rowsum(cbind(p$frac * fin, p$w * fin, p$w * v0, p$w * v0 * v0), p$region_id)
    id <- as.integer(rownames(a))
    data.frame(set = s, region_id = id, n = a[, 1], sumw = a[, 2], sumwx = a[, 3], sumwx2 = a[, 4],
               domain_km2 = as.numeric(domain_km2[[s]][as.character(id)]))
  }))
}
put <- function(d, kind, product, variant, date) {
  f <- file.path("data/sums", kind, paste0(product, "_", variant), paste0(format(date), ".parquet"))
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  d$date <- date
  nanoparquet::write_parquet(d, f)
}

overlap <- list()
for (product in names(stores)) {
  dsn <- setNames(paste0(B, stores[[product]]), names(stores[[product]]))
  ti <- lapply(dsn, time_index)
  t0 <- Sys.time()
  blk <- lapply(setNames(c("so", "aus"), c("so", "aus")), function(g)
    lapply(setNames(vars, vars), function(v) read_block(dsn[[g]], v, ti[[g]], g)))
  message(sprintf("%-6s read %d dates x %d vars x 2 stores in %.0f s", product, length(dates), length(vars),
                  as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  for (k in seq_along(dates)) {
    t0 <- Sys.time()
    comp <- lapply(setNames(vars, vars), function(v) rep(NA_real_, NC * NR))
    raw <- list()
    for (g in c("so", "aus")) {     # aus last: it wins where both exist
      for (v in vars) {
        val <- as.vector(blk[[g]][[v]][, , k])
        comp[[v]][pix[[g]]] <- val
        if (v == "sea_surface_temperature") raw[[g]] <- val
      }
    }
    ## Australia vs SO store where both domains exist (as-stored SST)
    ov <- intersect(pix$aus, pix$so)
    a <- raw$aus[match(ov, pix$aus)]; s <- raw$so[match(ov, pix$so)]
    both <- is.finite(a) & is.finite(s)
    overlap[[length(overlap) + 1]] <- data.frame(product = product, date = dates[k],
      pixels = length(ov), both = sum(both), aus_only = sum(is.finite(a) & !is.finite(s)),
      so_only = sum(!is.finite(a) & is.finite(s)), identical = sum(a[both] == s[both]),
      mean_diff = mean(a[both] - s[both]), max_abs_diff = max(abs(a[both] - s[both])))
    sst <- comp$sea_surface_temperature - 273.15
    q4 <- is.finite(comp$quality_level) & comp$quality_level >= 4
    var_x <- list(all = sst, q4 = ifelse(q4, sst, NA), q4b = ifelse(q4, sst - comp$sses_bias, NA))
    for (vn in names(var_x)) {
      put(sums_s2(var_x[[vn]]), "s2l5", product, vn, dates[k])
      put(sums_reg(var_x[[vn]]), "regions", product, vn, dates[k])
    }
    message(sprintf("%-6s %s  %.0f s", product, dates[k], as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  rm(blk); gc()
}
ov <- do.call(rbind, overlap)
write.csv(ov, "boundaries/overlap_check.csv", row.names = FALSE)
print(ov, row.names = FALSE)
