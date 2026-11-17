# Sparse pixel -> region coverage tables on the union 0.02 degree lattice.
#
# One table per region set: data/coverage/<set>.parquet with columns
#   region_id, row, col_start, col_end, fraction
# (rows and cols 1-based on the union grid, rows from the top; interior runs
# have fraction 1, boundary cells one row each with their exact fraction).
# Any product on the lattice reads its own window: union (row, col) minus the
# product's offsets in boundaries/lattice.csv.
#
# Check: sum(fraction * cell area) per region against the region's geodesic
# area, written to boundaries/coverage_check.csv (committed).
#
# usage (from the repo root): Rscript R/03_coverage.R
suppressPackageStartupMessages({ library(sf); library(controlledburn) })
lat <- read.csv("boundaries/lattice.csv")
u <- lat[lat$grid == "union", ]
ext <- c(u$xmin, u$xmax, u$ymin, u$ymax)
dm <- c(u$ncol, u$nrow)
res <- 0.02

## WGS84 ellipsoid area of a lon/lat cell, per row of the union grid
cell_km2 <- function(nrow, ymax, res) {
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  bot <- top - res * pi / 180
  (b^2 / 2) * (g(top) - g(bot)) * (res * pi / 180) / 1e6
}
stopifnot(abs(sum(cell_km2(9000, 90, 0.02)) * 18000 / 510065621.7 - 1) < 1e-9)  # whole ellipsoid
rowarea <- cell_km2(u$nrow, u$ymax, res)

dir.create("data/coverage", recursive = TRUE, showWarnings = FALSE)
sets <- c("eez_legal", "eez", "star", "imcra", "amp")
checks <- list()
for (s in sets) {
  x <- read_sf(file.path("data/boundaries", paste0(s, ".parquet")))
  t0 <- Sys.time()
  r <- burn(st_geometry(x), extent = ext, dimension = dm, threads = 8L)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  runs <- r$runs; edges <- r$edges
  tab <- rbind(
    data.frame(region_id = x$region_id[runs$id], row = runs$row, col_start = runs$col_start,
               col_end = runs$col_end, fraction = 1),
    data.frame(region_id = x$region_id[edges$id], row = edges$row, col_start = edges$col,
               col_end = edges$col, fraction = edges$fraction))
  tab <- tab[order(tab$region_id, tab$row, tab$col_start), ]
  nanoparquet::write_parquet(tab, file.path("data/coverage", paste0(s, ".parquet")))
  cov <- tapply((tab$col_end - tab$col_start + 1) * tab$fraction * rowarea[tab$row],
                factor(tab$region_id, levels = x$region_id), sum)
  cov[is.na(cov)] <- 0
  ncell <- tapply(tab$col_end - tab$col_start + 1, factor(tab$region_id, levels = x$region_id), sum)
  checks[[s]] <- data.frame(set = s, region_id = x$region_id, region = x$region,
                            cells = as.integer(ifelse(is.na(ncell), 0, ncell)),
                            coverage_km2 = round(as.numeric(cov), 2),
                            geod_km2 = round(x$geod_km2, 2),
                            rel_diff = signif(as.numeric(cov) / x$geod_km2 - 1, 3))
  message(sprintf("%-10s %4d regions  %9d rows in table  %6.1f s burn  total rel diff %+.2e",
                  s, nrow(x), nrow(tab), el, sum(cov) / sum(x$geod_km2) - 1))
}
chk <- do.call(rbind, checks)
write.csv(chk, "boundaries/coverage_check.csv", row.names = FALSE)
