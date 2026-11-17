# fv01 vs fv02 offset of BoM's L3S SST (qm43; BoM ABOM GHRSST L3S 1-day
# day+night, the gappy 0.02 degree composites, not MUR), on every day both
# versions exist, as exact mergeable sums.
#
# Products (qm43 directory, file window on the 0.02 degree lattice):
#   cont_avhrr   Continental AVHRR_D      aus  70-190E, 70S-20N
#   cont_multi   Continental MultiSensor  aus
#   south_avhrr  Southern AVHRR_D         so   2.5-202.5E, 77.5S-27.5S
#   south_multi  Southern MultiSensor     so
# Variants (applied to each version with its own quality_level/sses_bias):
#   all = every finite SST; q4 = quality_level >= 4; q4b = q4, SST - sses_bias
# d = fv01 - fv02 (degrees C) on pixels valid in both under the variant.
#
# Groupings: "domain" (the whole window), the region sets of R/03 (weight
# w = cell km2 x coverage, n = sum of coverage), and S2 L5 cells (trend.sst:
# w = cos(lat), n = pixels). Per group, three sets of sums:
#   both: n_both sumw_both sumwd sumwd2 sumwx02_both  (paired pixels)
#   fv01: n_01 sumw_01 sumwx_01 sumwx2_01              (fv01's own valid pixels)
#   fv02: n_02 sumw_02 sumwx_02 sumwx2_02              (fv02's own valid pixels)
#
# Output, one file per product-month (resumable: existing files are skipped):
#   OUT/<product>/<YYYY-MM>.rds = list(
#     regions       daily sums: domain and every region set except amp
#     regions_month monthly sums (sums of the daily sums): domain and every set incl. amp
#     s2            monthly sums per S2 L5 cell
#     days          per-day log: files, pixel counts, q4 domain offset, read/total seconds, errors)
#   Monthly rows carry `days`, the number of days with any valid pixel in the group.
#
# usage: Rscript offset.R <qm43 inventory.tsv.gz> <offset_kit.rds> <OUT> [QM43_ROOT]
# env:   PRODUCTS=cont_multi,...  YEARS=2020,2021  MONTHS=2024-01  NWORK=10
#        MAXDAYS=n (first n days of each month: for testing)
suppressPackageStartupMessages({ library(gdalraster); library(parallel) })
args <- commandArgs(TRUE)
inv_f <- args[1]; kit_f <- args[2]; out <- args[3]
root <- if (length(args) >= 4) args[4] else "/g/data/qm43/ghrsst"
env <- function(k, d = "") { v <- Sys.getenv(k); if (nzchar(v)) v else d }
split_env <- function(k) { v <- env(k); if (nzchar(v)) strsplit(v, ",")[[1]] else NULL }
NWORK <- as.integer(env("NWORK", "4")); MAXDAYS <- as.integer(env("MAXDAYS", "0"))
set_config_option("GDAL_NUM_THREADS", "1"); set_config_option("GDAL_CACHEMAX", "256")
set_config_option("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
set_config_option("GDAL_HTTP_TIMEOUT", "120"); set_config_option("GDAL_HTTP_MAX_RETRY", "3")

prods <- data.frame(product = c("cont_avhrr", "cont_multi", "south_avhrr", "south_multi"),
                    domain = c("Continental", "Continental", "Southern", "Southern"),
                    sensor = c("AVHRR_D", "MultiSensor", "AVHRR_D", "MultiSensor"),
                    window = c("aus", "aus", "so", "so"))
if (!is.null(split_env("PRODUCTS"))) prods <- prods[prods$product %in% split_env("PRODUCTS"), ]
variants <- c("all", "q4", "q4b")

## ---- day pairs from the qm43 inventory -------------------------------------
inv <- read.delim(gzfile(inv_f), header = FALSE, col.names = c("path", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
inv <- inv[grepl("^v02\\.0fv0[12]/(L3S-01day|L3S-01day-Southern|Continental/L3S-01day|Southern/L3S-01day-Southern)/dn/[0-9]{4}/[0-9]{14}-ABOM-L3S_GHRSST-SSTfnd-(AVHRR_D|MultiSensor)-1d_dn(_Southern)?-v02\\.0-fv0[12]\\.0\\.nc$", inv$path) &
             inv$size > 0, ]
b <- basename(inv$path)
inv$date <- as.Date(substr(b, 1, 8), "%Y%m%d")
inv$version <- sub(".*-(fv0[12])\\.0\\.nc$", "\\1", b)
inv$domain <- ifelse(grepl("_Southern-", b), "Southern", "Continental")
inv$sensor <- sub("^.*-SSTfnd-(.*)-1d_dn.*$", "\\1", b)
inv <- inv[order(-inv$size), ]
dup <- duplicated(inv[c("domain", "sensor", "version", "date")])
if (any(dup)) message(sum(dup), " duplicate (product, version, day) files; keeping the largest")
inv <- inv[!dup, ]
v1 <- inv[inv$version == "fv01", c("domain", "sensor", "date", "path")]
v2 <- inv[inv$version == "fv02", c("domain", "sensor", "date", "path")]
pairs <- merge(v1, v2, by = c("domain", "sensor", "date"), suffixes = c("01", "02"))
pairs <- merge(pairs, prods, by = c("domain", "sensor"))
pairs$month <- format(pairs$date, "%Y-%m")
if (!is.null(split_env("YEARS"))) pairs <- pairs[format(pairs$date, "%Y") %in% split_env("YEARS"), ]
if (!is.null(split_env("MONTHS"))) pairs <- pairs[pairs$month %in% split_env("MONTHS"), ]
pairs <- pairs[order(pairs$product, pairs$date), ]
rm(inv, v1, v2, b); invisible(gc())
tasks <- unique(pairs[c("product", "window", "month")])
tasks$file <- file.path(out, tasks$product, paste0(tasks$month, ".rds"))
cat("day pairs:", nrow(pairs), " product-months:", nrow(tasks), " already done:", sum(file.exists(tasks$file)), "\n")
print(table(pairs$product))
tasks <- tasks[!file.exists(tasks$file), ]
if (!nrow(tasks)) quit(save = "no")

## ---- geometry, expanded once (shared by the forked workers) ----------------
## Dense groupings (domain, S2 cells) go through "runs": stretches of one row
## with one S2 cell. Weights depend only on the row, so sums over a run's
## pixels, times the run's weight, give both the S2 and the domain sums.
## Region sets are stacked into one grouping (gid = set offset + region_id).
## Grouped sums are rowsum (exact double sums), one call per grouping.
kit <- readRDS(kit_f)
kit_cells <- kit$cells
geo <- lapply(kit$windows[unique(tasks$window)], function(w) {
  N <- w$ncol * w$nrow
  s2 <- inverse.rle(list(lengths = w$s2_lengths, values = w$s2_values))
  new_run <- c(TRUE, s2[-1L] != s2[-N]) | ((seq_len(N) - 1L) %% w$ncol == 0L)
  run_start <- which(new_run)
  run_row <- (run_start - 1L) %/% w$ncol + 1L
  sets <- names(w$regions)
  off <- cumsum(c(0L, vapply(w$regions, function(t) max(c(0L, t$region_id)), integer(1))))
  R <- do.call(rbind, lapply(seq_along(sets), function(i) {
    tab <- w$regions[[i]]
    len <- tab$col_end - tab$col_start + 1L
    rr <- rep(tab$row, len); frac <- rep(tab$fraction, len)
    data.frame(gid = off[i] + rep(tab$region_id, len),
               pix = sequence(len, from = tab$col_start) + (rr - 1L) * w$ncol,
               nw = frac, w = frac * w$km2_row[rr])
  }))
  R <- R[order(R$gid), ]
  gid_set <- rep(sets, diff(off)); gid_region <- sequence(diff(off))
  list(ncol = w$ncol, nrow = w$nrow, xmin = w$xmin, ymax = w$ymax, res = w$res, N = N,
       run = cumsum(new_run), run_cell = s2[run_start], run_w_s2 = w$s2_w_row[run_row], run_km2 = w$km2_row[run_row],
       R_gid = R$gid, R_pix = R$pix, R_nw = R$nw, R_w = R$w, gid_set = gid_set, gid_region = gid_region)
})
rm(kit)

## ---- reading ----------------------------------------------------------------
rd <- function(f, v, W) {
  ds <- new(GDALRaster, sprintf("NETCDF:\"%s\":%s", f, v))
  on.exit(ds$close())
  nx <- ds$getRasterXSize(); ny <- ds$getRasterYSize(); gt <- ds$getGeoTransform()
  if (nx != W$ncol || ny != W$nrow) stop(sprintf("%s: %dx%d, expected %dx%d", basename(f), nx, ny, W$ncol, W$nrow))
  dx0 <- ((gt[1] - W$xmin + 180) %% 360) - 180   # fv01 Continental stores lon wrapped: GDAL gives -290 for 70
  south_up <- gt[6] > 0
  y0 <- if (south_up) gt[4] + ny * gt[6] else gt[4]
  if (abs(dx0) > 1e-3 || abs(y0 - W$ymax) > 1e-3 || abs(gt[2] - W$res) > 1e-6 || abs(abs(gt[6]) - W$res) > 1e-6)
    stop(sprintf("%s: geotransform %s does not fit the lattice", basename(f), paste(signif(gt, 8), collapse = " ")))
  x <- ds$read(1, 0, 0, nx, ny, nx, ny)
  nd <- ds$getNoDataValue(1); sc <- ds$getScale(1); of <- ds$getOffset(1)
  if (!is.na(nd)) x[x == nd] <- NA
  x <- x * ifelse(is.na(sc), 1, sc) + ifelse(is.na(of), 0, of)
  if (south_up) x <- as.vector(matrix(x, nx)[, ny:1])
  x
}
## both versions, kept only at pixels where either has a finite SST
read_pair <- function(f1, f2, W) {
  s1 <- rd(f1, "sea_surface_temperature", W); s2 <- rd(f2, "sea_surface_temperature", W)
  k <- which(is.finite(s1) | is.finite(s2))
  sub <- function(f, v) rd(f, v, W)[k]
  list(k = k,
       a = list(sst = s1[k] - 273.15, ql = sub(f1, "quality_level"), sb = sub(f1, "sses_bias")),
       b = list(sst = s2[k] - 273.15, ql = sub(f2, "quality_level"), sb = sub(f2, "sses_bias")))
}
variant_x <- function(x, v) {
  if (v == "all") return(x$sst)
  y <- x$sst; y[!(is.finite(x$ql) & x$ql >= 4)] <- NA
  if (v == "q4b") y <- y - x$sb
  y
}

## ---- sums -------------------------------------------------------------------
cols <- c("n_both", "sumw_both", "sumwd", "sumwd2", "sumwx02_both", "n_01", "sumw_01", "sumwx_01", "sumwx2_01",
          "n_02", "sumw_02", "sumwx_02", "sumwx2_02")
## the 10 per-pixel quantities, in the order of the weighted columns of `cols`
## (cb, c1, c2 are the indicators whose unweighted sums are the n columns)
quantities <- c("cb", "d", "d2", "x2b", "c1", "x1", "x1sq", "c2", "x2", "x2sq")
qty <- function(j, a0, b0, fa, fb, cb) switch(j,
  cb = as.double(cb), d = (a0 - b0) * cb, d2 = ((a0 - b0) * cb)^2, x2b = b0 * cb,
  c1 = as.double(fa), x1 = a0, x1sq = a0 * a0, c2 = as.double(fb), x2 = b0, x2sq = b0 * b0)
## n x 13 in `cols` order from unweighted (U) and weighted (Wt) n x 10 sums
assemble <- function(U, Wt) {
  m <- cbind(U[, "cb", drop = FALSE], Wt[, c("cb", "d", "d2", "x2b"), drop = FALSE], U[, "c1", drop = FALSE],
             Wt[, c("c1", "x1", "x1sq"), drop = FALSE], U[, "c2", drop = FALSE], Wt[, c("c2", "x2", "x2sq"), drop = FALSE])
  colnames(m) <- cols; m
}

one_day <- function(p, W) {
  t0 <- Sys.time()
  P <- read_pair(file.path(root, p$path01), file.path(root, p$path02), W)
  read_s <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  k <- P$k
  rk <- W$run[k]    # run of each kept pixel
  ## region rows whose pixel is kept, as positions in k
  L <- integer(W$N); L[k] <- seq_along(k)
  pos <- L[W$R_pix]; keep <- which(pos > 0L); pos <- pos[keep]
  gid <- W$R_gid[keep]
  Rw <- W$R_w[keep]; Rnw <- W$R_nw[keep]
  rm(L)
  reg <- list(); s2 <- list(); info <- list()
  for (v in variants) {
    a <- variant_x(P$a, v); b <- variant_x(P$b, v)
    fa <- is.finite(a); fb <- is.finite(b); cb <- fa & fb
    a0 <- a; a0[!fa] <- 0; b0 <- b; b0[!fb] <- 0
    ## per-pixel quantities, one exact grouped sum per grouping (rowsum)
    Q <- vapply(quantities, qty, numeric(length(k)), a0 = a0, b0 = b0, fa = fa, fb = fb, cb = cb)
    rm(a, b, a0, b0, fa, fb, cb)
    U <- rowsum(Q, rk, reorder = FALSE)                                   # runs x 10
    runs <- as.integer(rownames(U))
    QP <- Q[pos, , drop = FALSE]; rm(Q)
    RW <- rowsum(QP * Rw, gid, reorder = FALSE)                           # regions x 10, weight w
    RN <- rowsum(QP[, c("cb", "c1", "c2"), drop = FALSE] * Rnw, gid, reorder = FALSE)   # weight nw (coverage)
    rm(QP)
    gids <- as.integer(rownames(RW))
    dm <- assemble(matrix(colSums(U), 1, dimnames = list(NULL, quantities)),
                   matrix(colSums(U * W$run_km2[runs]), 1, dimnames = list(NULL, quantities)))
    sm <- assemble(U, U * W$run_w_s2[runs])
    S <- matrix(0, length(kit_cells), 13, dimnames = list(NULL, cols))
    ss <- rowsum(sm, W$run_cell[runs], reorder = FALSE)
    S[as.integer(rownames(ss)), ] <- ss
    gm <- assemble(RN, RW)   # assemble reads only the cb/c1/c2 columns of its first argument
    keep_g <- which(gm[, "n_01"] > 0 | gm[, "n_02"] > 0)
    reg[[v]] <- rbind(data.frame(date = p$date, variant = v, set = "domain", region_id = 1L, dm),
                      data.frame(date = p$date, variant = v, set = W$gid_set[gids[keep_g]], region_id = W$gid_region[gids[keep_g]],
                                 gm[keep_g, , drop = FALSE]))
    s2[[v]] <- S
    info[[v]] <- dm
  }
  rownames_reset <- function(d) { rownames(d) <- NULL; d }
  list(regions = rownames_reset(do.call(rbind, reg)), s2 = s2,
       day = data.frame(date = p$date, file01 = basename(p$path01), file02 = basename(p$path02),
                        n01_all = info$all[, "n_01"], n02_all = info$all[, "n_02"], nboth_q4 = info$q4[, "n_both"],
                        mean_d_q4 = info$q4[, "sumwd"] / info$q4[, "sumw_both"], read_s = read_s))
}
## ---- one task = one product-month, all its days ------------------------------
run_task <- function(i) {
  t <- tasks[i, ]; W <- geo[[t$window]]
  P <- pairs[pairs$product == t$product & pairs$month == t$month, ]
  if (MAXDAYS > 0) P <- head(P, MAXDAYS)
  regs <- list(); days <- list(); s2 <- NULL; nday <- 0L
  for (j in seq_len(nrow(P))) {
    t0 <- Sys.time()
    r <- tryCatch(one_day(P[j, ], W), error = function(e) conditionMessage(e))
    el <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
    if (is.character(r)) {
      days[[j]] <- data.frame(date = P$date[j], file01 = basename(P$path01[j]), file02 = basename(P$path02[j]),
                              n01_all = NA, n02_all = NA, nboth_q4 = NA, mean_d_q4 = NA, read_s = NA, seconds = el, error = r)
      next
    }
    regs[[j]] <- r$regions
    days[[j]] <- cbind(r$day, seconds = el, error = "")
    s2 <- if (is.null(s2)) r$s2 else Map(`+`, s2, r$s2)
    nday <- nday + 1L
  }
  s2df <- if (is.null(s2)) NULL else do.call(rbind, lapply(names(s2), function(v) {
    m <- s2[[v]]; keep <- which(m[, "n_01"] > 0 | m[, "n_02"] > 0)
    data.frame(month = t$month, variant = v, cell = kit_cells[keep], days = nday, m[keep, , drop = FALSE])
  }))
  daily <- do.call(rbind, regs)
  monthly <- NULL
  if (!is.null(daily)) {
    key <- paste(daily$variant, daily$set, daily$region_id, sep = "|")
    sm <- rowsum(as.matrix(daily[cols]), key, reorder = FALSE)
    kk <- do.call(rbind, strsplit(rownames(sm), "|", fixed = TRUE))
    monthly <- data.frame(month = t$month, variant = kk[, 1], set = kk[, 2], region_id = as.integer(kk[, 3]),
                          days = as.integer(table(key)[rownames(sm)]), sm, row.names = NULL)
    daily <- daily[daily$set != "amp", ]
    rownames(daily) <- NULL
  }
  res <- list(product = t$product, month = t$month, regions = daily, regions_month = monthly, s2 = s2df,
              days = do.call(rbind, days))
  dir.create(dirname(t$file), recursive = TRUE, showWarnings = FALSE)
  saveRDS(res, paste0(t$file, ".tmp")); file.rename(paste0(t$file, ".tmp"), t$file)
  sprintf("%s %s: %d/%d days, %s s/day (read %s)%s", t$product, t$month, nday, nrow(P),
          format(round(mean(res$days$seconds), 1)), format(round(mean(res$days$read_s, na.rm = TRUE), 1)), if (nday < nrow(P)) paste0("; error: ", res$days$error[res$days$error != ""][1]) else "")
}
cat("workers:", NWORK, " tasks:", nrow(tasks), "\n")
t0 <- Sys.time()
msg <- mclapply(seq_len(nrow(tasks)), function(i) tryCatch(run_task(i), error = function(e) paste("task failed:", tasks$product[i], tasks$month[i], conditionMessage(e))),
                mc.cores = NWORK, mc.preschedule = FALSE)
for (m in msg) cat(if (is.character(m)) m else paste("worker error:", as.character(m)), "\n")
cat(sprintf("done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
