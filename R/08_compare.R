# Compare the 5-day IMOS L3S block with trend.sst (OISST, GHRSST MUR) on S2
# L5 cells, and measure what the L5 cell approximation costs for EEZ
# territories.
#
# Everything here is arithmetic on sums: daily sums add to 5-day sums;
# mean = sumwx / sumw, sd from sumwx2.
#
# Inputs: data/sums/{s2l5,regions}/<product>_<variant>/<date>.parquet (R/07),
# data/trend/{oisst,ghrsst}/<date>.parquet (trend.sst sums: OISST local,
# MUR from Acacia). Writes notes/block_2024-01-04.md and
# boundaries/block_2024-01-04_*.csv.
#
# usage (from the repo root): Rscript R/08_compare.R
suppressPackageStartupMessages(library(sf))
dates <- as.Date("2024-01-04") + 0:4
rd <- function(dir) {
  f <- file.path(dir, paste0(format(dates), ".parquet"))
  do.call(rbind, lapply(f, function(x) as.data.frame(nanoparquet::read_parquet(x))))
}
agg5 <- function(d, by) {   # 5-day sums: associativity
  s <- rowsum(as.matrix(d[c("n", "sumw", "sumwx", "sumwx2")]), interaction(d[by], drop = TRUE, lex.order = TRUE))
  k <- do.call(rbind, strsplit(rownames(s), ".", fixed = TRUE))
  out <- as.data.frame(k, stringsAsFactors = FALSE); names(out) <- by
  cbind(out, as.data.frame(s))
}
mean_sd <- function(d) within(d, { mean <- sumwx / sumw; sd <- sqrt(pmax(sumwx2 / sumw - mean^2, 0)) })

## ---- domain share per S2 cell (aus U so windows), from the mapping ----------
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
reg <- nanoparquet::read_parquet(map$registry)
s2i <- as.vector(t(map$idx)); pa <- rep(rowarea, each = NC)
inside <- rowsum(pa[dom], s2i[dom])
share <- data.frame(cell = reg$cell[as.integer(rownames(inside))], dom_km2 = inside[, 1])
share$share <- share$dom_km2 / reg$area_km2[match(share$cell, reg$cell)]
whole <- share$cell[share$share > 0.99]
reg$lat_band <- cut(reg$lat, c(-90, -60, -40, -20, 0, 30), labels = c("<60S", "60-40S", "40-20S", "20S-0", "0-30N"))

## ---- per-cell 5-day means ------------------------------------------------------
ref <- list(oisst = mean_sd(agg5(rd("data/trend/oisst"), "cell")),
            mur = mean_sd(agg5(rd("data/trend/ghrsst"), "cell")))
prods <- expand.grid(product = c("multi", "single"), variant = c("all", "q4", "q4b"), stringsAsFactors = FALSE)
cells <- list(); daily <- list()
for (i in seq_len(nrow(prods))) {
  p <- prods$product[i]; v <- prods$variant[i]
  d <- rd(file.path("data/sums/s2l5", paste0(p, "_", v)))
  x <- mean_sd(agg5(d, "cell"))
  x <- x[x$cell %in% whole, ]
  m <- merge(x[c("cell", "n", "mean", "sd")], setNames(ref$mur[c("cell", "n", "mean")], c("cell", "n_mur", "mur")), by = "cell")
  m <- merge(m, setNames(ref$oisst[c("cell", "mean")], c("cell", "oisst")), by = "cell")
  m$obs_frac <- m$n / (m$n_mur / 4)              # clear-sky share of ocean pixel-days: both are 5-day sums; MUR 0.01 deg ~ 4 px per 0.02 deg px
  m$product <- p; m$variant <- v
  m$lat_band <- reg$lat_band[match(m$cell, reg$cell)]
  cells[[i]] <- m
}
cells <- do.call(rbind, cells)
write.csv(cells, "boundaries/block_2024-01-04_cells.csv", row.names = FALSE)

stat <- function(x) c(cells = length(x), median = median(x), mean = mean(x), sd = sd(x), rms = sqrt(mean(x^2)))
use <- cells$obs_frac >= 0.2
tab <- do.call(rbind, lapply(split(cells[use, ], list(cells$product[use], cells$variant[use]), drop = TRUE), function(m) {
  data.frame(product = m$product[1], variant = m$variant[1], obs_frac = median(m$obs_frac),
             t(round(stat(m$mean - m$mur), 3)), oisst_rms = round(sqrt(mean((m$mean - m$oisst)^2)), 3),
             mur_minus_oisst_rms = round(sqrt(mean((m$mur - m$oisst)^2)), 3))
}))
band <- do.call(rbind, lapply(split(cells[use & cells$variant == "q4", ], list(cells$product[use & cells$variant == "q4"], cells$lat_band[use & cells$variant == "q4"]), drop = TRUE), function(m) {
  data.frame(product = m$product[1], lat_band = as.character(m$lat_band[1]), cells = nrow(m),
             obs_frac = round(median(m$obs_frac), 2), l3s_minus_mur = round(median(m$mean - m$mur), 3),
             rms_vs_mur = round(sqrt(mean((m$mean - m$mur)^2)), 3), mur_minus_oisst = round(median(m$mur - m$oisst), 3))
}))

## ---- EEZ territories: exact region mean vs L5 cell selections ------------------
## overlap of every (territory, S2 cell) pair, exact at 0.02 deg, from the coverage table
eez <- read_sf("data/boundaries/eez.parquet")
tab_e <- nanoparquet::read_parquet("data/coverage/eez.parquet")
len <- tab_e$col_end - tab_e$col_start + 1; rr <- rep(tab_e$row, len)
pe <- data.frame(region_id = rep(tab_e$region_id, len), pix = sequence(len, from = tab_e$col_start) + (rr - 1) * NC,
                 w = rep(tab_e$fraction, len) * rowarea[rr])
pe$cell <- s2i[pe$pix]
ov <- aggregate(w ~ region_id + cell, pe, sum)
ov$cell_km2 <- reg$area_km2[ov$cell]; ov$cell_share <- ov$w / ov$cell_km2
regsum <- mean_sd(agg5(rd("data/sums/regions/multi_q4")[rd("data/sums/regions/multi_q4")$set == "eez", ], "region_id"))
s2m <- mean_sd(agg5(rd("data/sums/s2l5/multi_q4"), "cell"))
pool <- function(sel, sums) {    # mean over a cell selection = sum of sums
  s <- sums[sums$cell %in% sel, ]
  sum(s$sumwx) / sum(s$sumw)
}
eez_tab <- do.call(rbind, lapply(seq_len(nrow(eez)), function(i) {
  o <- ov[ov$region_id == eez$region_id[i], ]
  any_sel <- reg$cell[o$cell]; maj_sel <- reg$cell[o$cell[o$cell_share >= 0.5]]
  data.frame(territory = eez$region[i], region_km2 = round(eez$geod_km2[i]),
             l3s_exact = round(regsum$mean[regsum$region_id == as.character(eez$region_id[i])], 3),
             cells_any = length(any_sel), any_km2_ratio = round(sum(o$cell_km2) / eez$geod_km2[i], 2),
             l3s_any = round(pool(any_sel, s2m), 3), mur_any = round(pool(any_sel, ref$mur), 3), oisst_any = round(pool(any_sel, ref$oisst), 3),
             cells_major = length(maj_sel),
             l3s_major = if (length(maj_sel)) round(pool(maj_sel, s2m), 3) else NA,
             mur_major = if (length(maj_sel)) round(pool(maj_sel, ref$mur), 3) else NA)
}))
write.csv(tab, "boundaries/block_2024-01-04_summary.csv", row.names = FALSE)
write.csv(band, "boundaries/block_2024-01-04_bands.csv", row.names = FALSE)
write.csv(eez_tab, "boundaries/block_2024-01-04_eez.csv", row.names = FALSE)
print(tab, row.names = FALSE); print(band, row.names = FALSE); print(eez_tab, row.names = FALSE)
