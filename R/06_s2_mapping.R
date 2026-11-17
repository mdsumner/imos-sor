# Dense pixel -> S2 cell mapping for the union 0.02 degree lattice, in the
# trend.sst convention: a pixel belongs to the cell containing its centre,
# weight cos(lat), registry index into trend.sst's s2_registry.parquet.
#
# Writes data/mapping/union_s2l5.rds: list(idx = integer matrix [row, col] of
# registry indices, rows from the top; w = cos(lat) per row; registry path;
# lattice). Also boundaries/s2l5_window_cells.csv: for each lattice window
# (union, aus, so), the share of each S2 cell's area inside it, so comparisons
# can keep only cells wholly inside a window.
#
# usage (from the repo root): Rscript R/06_s2_mapping.R
reg_path <- normalizePath("~/Git/trend.sst/s2_registry.parquet")
reg <- nanoparquet::read_parquet(reg_path)
level <- reg$level[1]
lat <- read.csv("boundaries/lattice.csv")
u <- lat[lat$grid == "union", ]
res <- 0.02
lons <- u$xmin + (seq_len(u$ncol) - 0.5) * res
lons <- ifelse(lons > 180, lons - 360, lons)        # s2 wants -180..180
lats <- u$ymax - (seq_len(u$nrow) - 0.5) * res

t0 <- Sys.time()
rows <- parallel::mclapply(seq_len(u$nrow), function(r) {
  tok <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_geog_point(lons, rep(lats[r], length(lons)))), level))
  i <- match(tok, reg$cell)
  stopifnot(!anyNA(i))
  i
}, mc.cores = 24L)
idx <- do.call(rbind, rows)
storage.mode(idx) <- "integer"
message(sprintf("mapping %d x %d in %.0f s", nrow(idx), ncol(idx), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
dir.create("data/mapping", recursive = TRUE, showWarnings = FALSE)
saveRDS(list(idx = idx, w = cos(lats * pi / 180), registry = reg_path, level = level, lattice = u),
        "data/mapping/union_s2l5.rds", compress = FALSE)

## share of each cell's area inside each window, from WGS84 cell areas
cell_km2 <- function(nrow, ymax, res) {
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  (b^2 / 2) * (g(top) - g(top - res * pi / 180)) * (res * pi / 180) / 1e6
}
ra <- cell_km2(u$nrow, u$ymax, res)
win <- lat[lat$grid %in% c("union", "aus", "so"), ]
out <- lapply(seq_len(nrow(win)), function(k) {
  wr <- win$row_offset[k] + seq_len(win$nrow[k]); wc <- win$col_offset[k] + seq_len(win$ncol[k])
  a <- rowsum(rep(ra[wr], times = length(wc)), as.vector(idx[wr, wc]))
  data.frame(window = win$grid[k], cell = reg$cell[as.integer(rownames(a))],
             inside_km2 = a[, 1], cell_km2 = reg$area_km2[as.integer(rownames(a))])
})
out <- do.call(rbind, out)
out$share <- round(out$inside_km2 / out$cell_km2, 4)
write.csv(out, "boundaries/s2l5_window_cells.csv", row.names = FALSE)
print(aggregate(share ~ window, out, function(s) c(cells = length(s), whole = sum(s > 0.99))))
