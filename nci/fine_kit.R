# Geometry for nci/sums_fine.R: finer S2 cells for one region's box, built
# here and copied to Gadi (base R only there).
#
# The box is the set of S2 L5 cells (R/06, the trend.sst registry) that touch
# a region (default STAR South-east). Every pixel of those L5 cells gets its
# S2 cell at LEVEL (default 8, about 33 km at 42 S), so each L5 cell is
# complete. Summed over children, the fine sums must equal the L5 sums of
# nci/sums.R, and R/10 checks that they do. The box lies in the Continental
# (aus) window of the BoM/IMOS ABOM GHRSST L3S files (not MUR), where the
# composite of nci/sums.R is always the Continental file.
#
# Holds the box's read window in aus-window pixels (0-based offsets), the
# fine cell of every box pixel (lon fastest, north-up; 0 = not in the L5
# cells), cos(lat) per box row (trend.sst's S2 weight, as R/06), the fine
# cell tokens and their L5 parents.
#
# Writes data/nci/fine_kit_<set>_<region_id>_l<LEVEL>.rds.
# usage (from the repo root): Rscript nci/fine_kit.R [set = star] [region_id = 4] [LEVEL = 8]
a <- commandArgs(TRUE)
set <- if (length(a) >= 1) a[1] else "star"
region_id <- if (length(a) >= 2) as.integer(a[2]) else 4L
LEVEL <- if (length(a) >= 3) as.integer(a[3]) else 8L
lat <- read.csv("boundaries/lattice.csv")
u <- lat[lat$grid == "union", ]; aw <- lat[lat$grid == "aus", ]; res <- 0.02
map <- readRDS("data/mapping/union_s2l5.rds")
reg <- nanoparquet::read_parquet(map$registry)
stopifnot(map$level == 5L, LEVEL > map$level)
rg <- read.csv("boundaries/regions.csv")
name <- rg$region[rg$set == set & rg$region_id == region_id]
stopifnot(length(name) == 1)

## the L5 cells that touch the region, and the box around them
cov <- nanoparquet::read_parquet(file.path("data/coverage", paste0(set, ".parquet")))
cov <- cov[cov$region_id == region_id, ]
len <- cov$col_end - cov$col_start + 1L
pix <- sequence(len, from = cov$col_start) + (rep(cov$row, len) - 1L) * u$ncol
l5 <- sort(unique(as.vector(t(map$idx))[pix]))
inset <- matrix(map$idx %in% l5, nrow(map$idx))
rows <- range(which(rowSums(inset) > 0)); cols <- range(which(colSums(inset) > 0))
## in the aus window
r0 <- rows[1] - aw$row_offset; r1 <- rows[2] - aw$row_offset
c0 <- cols[1] - aw$col_offset; c1 <- cols[2] - aw$col_offset
stopifnot(r0 >= 1, c0 >= 1, r1 <= aw$nrow, c1 <= aw$ncol)
nr <- r1 - r0 + 1L; nc <- c1 - c0 + 1L

## fine cell of each pixel centre in the L5 cells (as R/06)
lons <- u$xmin + (cols[1]:cols[2] - 0.5) * res; lons <- ifelse(lons > 180, lons - 360, lons)
lats <- u$ymax - (rows[1]:rows[2] - 0.5) * res
t0 <- Sys.time()
tok <- parallel::mclapply(seq_len(nr), function(i) {
  k <- inset[rows[1] + i - 1L, cols[1]:cols[2]]
  out <- rep(NA_character_, nc)
  if (any(k)) out[k] <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_geog_point(lons[k], rep(lats[i], sum(k)))), LEVEL))
  out
}, mc.cores = 16L)
tok <- do.call(rbind, tok)                                   # nr x nc, north-up
tokens <- sort(unique(tok[!is.na(tok)]))
cell <- match(as.vector(t(tok)), tokens); cell[is.na(cell)] <- 0L   # lon fastest
storage.mode(cell) <- "integer"
parent5 <- as.character(s2::s2_cell_parent(s2::as_s2_cell(tokens), 5L))
## the fine cells' L5 parents must be the L5 cells R/06 gave those pixels
l5_pix <- reg$cell[as.vector(t(map$idx[rows[1]:rows[2], cols[1]:cols[2]]))]
stopifnot(identical(parent5[cell[cell > 0]], l5_pix[cell > 0]), setequal(unique(parent5), reg$cell[l5]))
message(sprintf("%d fine cells (L%d) in %d L5 cells; %.0f s", length(tokens), LEVEL, length(l5),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))

kit <- list(set = set, region_id = region_id, region = name, level = LEVEL,
            aus = list(ncol = aw$ncol, nrow = aw$nrow, xmin = aw$xmin, ymax = aw$ymax, res = res),
            xoff = c0 - 1L, yoff = r0 - 1L, ncol = nc, nrow = nr,   # read window in the aus file, 0-based offsets
            union_rows = rows, union_cols = cols,
            cell = cell, w_row = cos(lats * pi / 180),
            tokens = tokens, parent5 = parent5, l5 = reg$cell[l5],
            made = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
out <- sprintf("data/nci/fine_kit_%s_%d_l%d.rds", set, region_id, LEVEL)
saveRDS(kit, out)
cat(sprintf("%s %d (%s): L5 cells %d, L%d cells %d; box %d x %d pixels at aus col %d, row %d (0-based); %d pixels in cells\n",
            set, region_id, name, length(l5), LEVEL, length(tokens), nc, nr, kit$xoff, kit$yoff, sum(cell > 0)))
cat(sprintf("box: lon %.2f .. %.2f, lat %.2f .. %.2f\n", u$xmin + (cols[1] - 1) * res, u$xmin + cols[2] * res,
            u$ymax - rows[2] * res, u$ymax - (rows[1] - 1) * res))
cat(out, file.size(out), "bytes\n")
