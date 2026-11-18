# Settings and functions shared by R/09_trends.R (S2 L5 cells and region
# sets) and R/10_fine_trends.R (finer S2 cells over one region's box), so
# both use the same climatologies, coverage rules and trend fits. Needs
# data.table. The method is described in R/09_trends.R and notes/trends.md.

## climatology base years per product, and the years needed per calendar month
base <- list(single = 1993:2022, multi = 2013:2022, single_night = 1993:2022)
min_clim_years <- list(single = 15, multi = 7, single_night = 15)
periods <- data.frame(period = c("1993-2016", "1993-2024", "2013-2024"), from = c(1993, 1993, 2013), to = c(2016, 2024, 2024))
rel_cov <- 0.2           # a cell- or region-month counts if its coverage is >= 20% of its own median
min_npix <- 30           # ... and (cells) it has >= 30 pixel-days
min_area_frac <- 0.5     # cell method: cells with a valid anomaly cover >= half the region's observable ocean
min_period_frac <- 0.8   # a trend needs >= 80% of the period's months
status_year <- 2024

## WGS84 area (km2) of a 0.02 degree pixel in each lattice row, from the top
cell_km2 <- function(nrow, ymax, res) {
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  (b^2 / 2) * (g(top) - g(top - res * pi / 180)) * (res * pi / 180) / 1e6
}
## months as year * 12 + month - 1
ym_of <- function(d) as.integer(format(d, "%Y")) * 12L + as.integer(format(d, "%m")) - 1L
days_in <- function(ym) { y <- ym %/% 12L; m <- ym %% 12L + 1L
  as.integer(as.Date(sprintf("%d-%02d-01", y + (m == 12L), m %% 12L + 1L)) - as.Date(sprintf("%d-%02d-01", y, m))) }

## x: key cols + ym + mean + ok; adds year, mon, clim (calendar-month mean over
## the product's base years) and anom (where ok)
clim_anom <- function(x, key, p) {
  x[, `:=`(year = ym %/% 12L, mon = ym %% 12L + 1L)]
  cl <- x[ok == TRUE & year %in% base[[p]], .(clim = mean(mean), clim_years = .N), by = c(key, "mon")][clim_years >= min_clim_years[[p]]]
  x <- merge(x, cl[, c(key, "mon", "clim"), with = FALSE], by = c(key, "mon"), all.x = TRUE)
  x[, anom := fifelse(ok, mean - clim, NA_real_)]
  x
}

## anomalies first: region anomaly = mean of its cells' anomalies, weighted by
## ov$w (the region's area in each cell, capped at the cell's ocean area); a
## month needs valid cells over min_area_frac of the observable area (cells
## with a climatology for that calendar month). ov: set, region_id, cell, w;
## cm: cell, ym, mon, clim, anom.
anom_cell_regions <- function(ov, cm) {
  a <- merge(ov, cm[is.finite(anom), .(cell, ym, anom)], by = "cell", allow.cartesian = TRUE)
  ca <- a[, .(anom_cell = sum(w * anom) / sum(w), w_valid = sum(w)), by = .(set, region_id, ym)]
  ob <- merge(ov, unique(cm[is.finite(clim), .(cell, mon)]), by = "cell", allow.cartesian = TRUE)[, .(w_obs = sum(w)), by = .(set, region_id, mon)]
  ca[, mon := ym %% 12L + 1L]
  ca <- merge(ca, ob, by = c("set", "region_id", "mon"))[, area_frac := w_valid / w_obs]
  ca[area_frac < min_area_frac, anom_cell := NA_real_]
  ca
}

## OLS on monthly anomalies; SE inflated for lag-1 autocorrelation; per decade
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
## trends for every period; d: key cols + ym + year + anom
trends_of <- function(d, key) rbindlist(lapply(seq_len(nrow(periods)), function(i) {
  P <- periods[i, ]; months <- (P$from * 12L):(P$to * 12L + 11L)
  x <- d[year >= P$from & year <= P$to]
  x <- x[, .SD[match(months, ym)][, ym := months], by = key]   # complete monthly axis, gaps as NA
  f <- x[, as.list(fit(ym / 12 + 1 / 24, anom)), by = key]
  f[, `:=`(period = P$period, months_frac = n / length(months))]
  f[months_frac < min_period_frac, c("slope", "se", "lo", "hi") := NA_real_]
  f
}))
