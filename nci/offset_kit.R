# Geometry for nci/offset.R, built here and copied to Gadi (base R only there).
#
# For each product window of the 0.02 degree L3S lattice (BoM/IMOS ABOM
# GHRSST L3S, not MUR): aus = Continental files (70-190E, 70S-20N),
# so = Southern files (2.5-202.5E, 77.5S-27.5S). Holds
#   - the region coverage tables (R/03: runs + edge cells, coverage fraction),
#     clipped and shifted to window rows/cols
#   - the S2 L5 cell of every pixel (R/06, trend.sst registry), run-length encoded
#     in the window's lon-fastest, north-up order
#   - cos(lat) per row (trend.sst's S2 weight) and WGS84 cell km2 per row
# plus the region names and the S2 cell tokens.
#
# Writes data/nci/offset_kit.rds (a few MB).
# usage (from the repo root): Rscript nci/offset_kit.R
lat <- read.csv("boundaries/lattice.csv")
u <- lat[lat$grid == "union", ]; NC <- u$ncol; NR <- u$nrow; res <- 0.02
cell_km2 <- function(nrow, ymax, res) {   # as R/07
  a <- 6378137; f <- 1 / 298.257223563; e2 <- f * (2 - f); e <- sqrt(e2); b <- a * (1 - f)
  g <- function(phi) { s <- sin(phi); s / (1 - e2 * s^2) + atanh(e * s) / e }
  top <- (ymax - (seq_len(nrow) - 1) * res) * pi / 180
  (b^2 / 2) * (g(top) - g(top - res * pi / 180)) * (res * pi / 180) / 1e6
}
rowarea <- cell_km2(NR, u$ymax, res)
map <- readRDS("data/mapping/union_s2l5.rds")
stopifnot(identical(dim(map$idx), c(NR, NC)))
reg <- nanoparquet::read_parquet(map$registry)
sets <- c("eez_legal", "eez", "star", "imcra", "amp")
cov <- lapply(setNames(sets, sets), function(s) as.data.frame(nanoparquet::read_parquet(file.path("data/coverage", paste0(s, ".parquet")))))

windows <- lapply(c(aus = "aus", so = "so"), function(g) {
  w <- lat[lat$grid == g, ]
  rows <- w$row_offset + seq_len(w$nrow); cols <- w$col_offset + seq_len(w$ncol)
  s2 <- rle(as.vector(t(map$idx[rows, cols])))      # lon fastest, north-up
  regions <- lapply(cov, function(tab) {
    tab <- tab[tab$row %in% rows, ]
    tab$row <- tab$row - w$row_offset
    tab$col_start <- pmax(tab$col_start - w$col_offset, 1L)
    tab$col_end <- pmin(tab$col_end - w$col_offset, w$ncol)
    tab <- tab[tab$col_start <= tab$col_end, ]
    rownames(tab) <- NULL
    tab
  })
  list(ncol = w$ncol, nrow = w$nrow, xmin = w$xmin, ymax = w$ymax, res = res,
       s2_lengths = s2$lengths, s2_values = s2$values,
       s2_w_row = map$w[rows], km2_row = rowarea[rows], regions = regions)
})
kit <- list(windows = windows, cells = reg$cell, level = map$level,
            regions = read.csv("boundaries/regions.csv")[c("set", "region_id", "region")],
            made = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
dir.create("data/nci", showWarnings = FALSE)
saveRDS(kit, "data/nci/offset_kit.rds")
for (g in names(windows)) {
  w <- windows[[g]]
  cat(sprintf("%-3s %dx%d  s2 runs %d (cells %d)  region pixels: %s\n", g, w$ncol, w$nrow, length(w$s2_lengths),
              length(unique(w$s2_values)),
              paste(sprintf("%s %d", names(w$regions), sapply(w$regions, function(t) sum(t$col_end - t$col_start + 1))), collapse = ", ")))
}
cat("data/nci/offset_kit.rds", file.size("data/nci/offset_kit.rds"), "bytes\n")
