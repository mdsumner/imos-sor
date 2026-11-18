# The IMOS L3S SST record as exact daily sums, read in situ on Gadi from
# sh74 (the IMOS/AODN mirror). These are the 1-day day+night ABOM GHRSST L3S
# composites at 0.02 degrees, not MUR. This is R/07 for whole records: the
# same products, variants, groupings and weights, so the output merges with
# R/07's block and with trend.sst.
#
# Products, each a composite on the union lattice (boundaries/lattice.csv):
# the Australia (Continental) window where it exists, the Southern Ocean
# window elsewhere. As in R/07 the Continental file wins wherever both
# windows cover a pixel, whether or not it has a value there. The overlap is
# never filled from the Southern file, so each pixel always has one source.
#   multi        = L3SM-1d/dn (aus) + L3SM-1dS/dn (so)   MultiSensor, day+night, SSTfnd
#   single       = L3S-1d/dn  (aus) + L3S-1dS/dn  (so)   AVHRR_D, day+night, SSTfnd
#   single_night = L3S-1d/ngt (aus only)                 AVHRR_D, night, SSTskin
# The night product (STAR 1.2's source) is skin SST, so it runs cooler than
# the foundation SST of the day+night composites. It has no Southern file,
# so its domain is the Continental window (OUT/domain_km2.rds, aus_km2).
# Screen (every variant): a pixel is dropped if l2p_flags has the ice bit
# (4), or if its SST is outside -2.5 .. 40 C. In the AVHRR record the
# ice-flagged pixels include the Ross Ice Shelf set to 52.0 C at quality 4-5,
# and one Southern file (1999-10-04) decodes to 2.4e36 C (notes/issues.md
# 19-20). The log counts what each window loses to each test.
# Variants: all = every screened SST; q4 = quality_level >= 4;
#           q4b = q4 and SST - sses_bias. SST in degrees C (K - 273.15).
# IMOS holds BoM fv02 to 2022-12-31 and fv01 after (nci/README.md).
#
# Groupings, each with n, sumw, sumwx, sumwx2:
#   S2 L5 cells   trend.sst: w = cos(lat), n = pixels
#   region sets   R/03 coverage: w = cell km2 x coverage, n = sum of coverage;
#                 every region in the domain, n = 0 included (as R/07)
#   domain        the whole composite: w = cell km2, n = pixels
# The sums are exact (rowsum over stretches of one row in one S2 cell, as in
# offset.R), so they add across days, cells and regions.
#
# Output, one file per product-month (resumable: existing files are skipped, unless REDO_FAILED=1 and the file logs a failed day):
#   OUT/<product>/<YYYY-MM>.rds = list(
#     s2       date, variant, cell (index into kit$cells), n, sumw, sumwx, sumwx2   (cells with n > 0)
#     regions  date, variant, set, region_id, n, sumw, sumwx, sumwx2               (incl. set "domain")
#     days     per-day log: the two files (or ""), stale flags, finite pixels per
#              window (n_aus, n_so) and how many the screen dropped (ice_*,
#              range_*), q4 count and q4b domain mean, seconds, error
#     screen   the screen used)
# plus OUT/domain_km2.rds (region area inside the composite domain, per set and
# region) and OUT/screen.rds. An OUT made with another screen (or none: the
# first run, before the screen) is refused, so runs can't mix.
# sums_to_parquet.R turns them into R/07's per-day parquet layout.
#
# A day is written if either window has a file. If one is missing its part of
# the domain is empty that day, and the log says so. If a file can't be read
# the whole day is dropped and logged. "Stale" marks sh74 files that S3 has
# since replaced (compare_inventory.R): their sums are written but flagged.
#
# usage: Rscript sums.R <sh74 inventory.tsv.gz> <offset_kit.rds> <OUT> [SH74_ROOT] [stale.csv]
#   SH74_ROOT default /g/data/sh74/IMOS_AODN; stale.csv = nci/compare-IMOS_SRS_SST_ghrsst-files.csv
# env:   PRODUCTS=multi,single  YEARS=2020,2021  MONTHS=2024-01  NWORK=4
#        MAXDAYS=n (first n days of each month: for testing)
#        REDO_FAILED=1 (also redo months whose file logs a failed day)
suppressPackageStartupMessages({ library(gdalraster); library(parallel) })
args <- commandArgs(TRUE)
inv_f <- args[1]; kit_f <- args[2]; out <- args[3]
root <- if (length(args) >= 4) args[4] else "/g/data/sh74/IMOS_AODN"
stale_f <- if (length(args) >= 5) args[5] else ""
env <- function(k, d = "") { v <- Sys.getenv(k); if (nzchar(v)) v else d }
split_env <- function(k) { v <- env(k); if (nzchar(v)) strsplit(v, ",")[[1]] else NULL }
NWORK <- as.integer(env("NWORK", "4")); MAXDAYS <- as.integer(env("MAXDAYS", "0"))
set_config_option("GDAL_NUM_THREADS", "1"); set_config_option("GDAL_CACHEMAX", "256")
set_config_option("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")

prods <- data.frame(product = c("multi", "multi", "single", "single", "single_night"),
                    dir = c("L3SM-1d/dn", "L3SM-1dS/dn", "L3S-1d/dn", "L3S-1dS/dn", "L3S-1d/ngt"),
                    window = c("aus", "so", "aus", "so", "aus"))
if (!is.null(split_env("PRODUCTS"))) prods <- prods[prods$product %in% split_env("PRODUCTS"), ]
variants <- c("all", "q4", "q4b")
screen <- list(ice_bit = 4L, sst_min = -2.5, sst_max = 40)

## ---- days from the sh74 inventory -----------------------------------------
inv <- read.delim(gzfile(inv_f), header = FALSE, col.names = c("path", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
re <- paste0("^IMOS/SRS/SST/ghrsst/(L3S-1d|L3SM-1d|L3S-1dS|L3SM-1dS)/",
             "(dn/[0-9]{4}/[0-9]{14}-ABOM-L3S_GHRSST-SSTfnd-(AVHRR_D|MultiSensor)-1d_dn(_Southern)?",
             "|ngt/[0-9]{4}/[0-9]{14}-ABOM-L3S_GHRSST-SSTskin-(AVHRR_D|MultiSensor)-1d_night)\\.nc$")
inv <- inv[grepl(re, inv$path) & inv$size > 0, ]
inv$dir <- sub("^IMOS/SRS/SST/ghrsst/([^/]+/[^/]+)/.*$", "\\1", inv$path)   # product directory and time of day
inv$date <- as.Date(substr(basename(inv$path), 1, 8), "%Y%m%d")
inv <- merge(inv, prods, by = "dir")
inv <- inv[order(-inv$size), ]
dup <- duplicated(inv[c("dir", "date")])
if (any(dup)) message(sum(dup), " duplicate (directory, day) files; keeping the largest")
inv <- inv[!dup, ]
stale <- character()
if (nzchar(stale_f) && file.exists(stale_f)) {
  s <- read.csv(stale_f, colClasses = "character")
  stale <- s$key[s$status == "size_differs"]
}
inv$stale <- inv$path %in% stale
cat("files:", nrow(inv), " stale vs S3:", sum(inv$stale), "\n")
w_aus <- inv[inv$window == "aus", c("product", "date", "path", "stale")]
w_so <- inv[inv$window == "so", c("product", "date", "path", "stale")]
days <- merge(w_aus, w_so, by = c("product", "date"), all = TRUE, suffixes = c("_aus", "_so"))
days$path_aus[is.na(days$path_aus)] <- ""; days$path_so[is.na(days$path_so)] <- ""
days$stale_aus <- days$stale_aus %in% TRUE; days$stale_so <- days$stale_so %in% TRUE
days$month <- format(days$date, "%Y-%m")
if (!is.null(split_env("YEARS"))) days <- days[format(days$date, "%Y") %in% split_env("YEARS"), ]
if (!is.null(split_env("MONTHS"))) days <- days[days$month %in% split_env("MONTHS"), ]
days <- days[order(days$product, days$date), ]
rm(inv, w_aus, w_so); invisible(gc())
print(do.call(rbind, lapply(split(days, days$product), function(x) data.frame(product = x$product[1], days = nrow(x),
  aus = sum(nzchar(x$path_aus)), so = sum(nzchar(x$path_so)), first = min(x$date), last = max(x$date)))), row.names = FALSE)
tasks <- unique(days[c("product", "month")])
tasks$file <- file.path(out, tasks$product, paste0(tasks$month, ".rds"))
cat("product-months:", nrow(tasks), " already done:", sum(file.exists(tasks$file)), "\n")

## ---- geometry, expanded once (shared by the forked workers) ----------------
## As offset.R: runs = stretches of one row with one S2 cell; region sets
## stacked into one grouping with gid = set offset + region_id. The offsets
## come from the full region list, so gids agree between the two windows.
kit <- readRDS(kit_f)
kit_cells <- kit$cells
sets <- unique(kit$regions$set)
nmax <- vapply(sets, function(s) max(kit$regions$region_id[kit$regions$set == s]), integer(1))
off <- setNames(cumsum(c(0L, nmax))[seq_along(sets)], sets); G <- sum(nmax)
gid_set <- rep(sets, nmax); gid_region <- sequence(nmax)
by_gid <- function(i, w) { o <- numeric(G); s <- rowsum(w, i); o[as.integer(rownames(s))] <- s[, 1]; o }
## the part of the so window that the aus window covers, as so rows and cols
ka <- kit$windows$aus; ks <- kit$windows$so
oc <- round((ka$xmin - ks$xmin) / ks$res) + seq_len(ka$ncol); oc <- oc[oc >= 1 & oc <= ks$ncol]
or <- round((ks$ymax - ka$ymax) / ks$res) + seq_len(ka$nrow); or <- or[or >= 1 & or <= ks$nrow]
cat(sprintf("so window: rows %d-%d, cols %d-%d come from the aus window\n", min(or), max(or), min(oc), max(oc)))
geo <- lapply(c(aus = "aus", so = "so"), function(g) {
  w <- kit$windows[[g]]
  N <- w$ncol * w$nrow
  use <- rep(TRUE, N)
  if (g == "so") use[as.vector(outer(oc, (or - 1L) * w$ncol, "+"))] <- FALSE
  s2 <- inverse.rle(list(lengths = w$s2_lengths, values = w$s2_values))
  new_run <- c(TRUE, s2[-1L] != s2[-N]) | ((seq_len(N) - 1L) %% w$ncol == 0L)
  run_start <- which(new_run)
  run_row <- (run_start - 1L) %/% w$ncol + 1L
  R <- do.call(rbind, lapply(names(w$regions), function(s) {
    tab <- w$regions[[s]]
    len <- tab$col_end - tab$col_start + 1L
    rr <- rep(tab$row, len); frac <- rep(tab$fraction, len)
    data.frame(gid = off[[s]] + rep(tab$region_id, len),
               pix = sequence(len, from = tab$col_start) + (rr - 1L) * w$ncol,
               nw = frac, w = frac * w$km2_row[rr])
  }))
  R <- R[use[R$pix], ]
  R <- R[order(R$gid), ]
  list(ncol = w$ncol, nrow = w$nrow, xmin = w$xmin, ymax = w$ymax, res = w$res, N = N,
       use = if (all(use)) NULL else use,
       run = cumsum(new_run), run_cell = s2[run_start], run_w_s2 = w$s2_w_row[run_row], run_km2 = w$km2_row[run_row],
       R_gid = R$gid, R_pix = R$pix, R_nw = R$nw, R_w = R$w,
       gid_km2 = by_gid(R$gid, R$w), km2 = sum(rep(w$km2_row, each = w$ncol)[use]))
})
rm(kit); invisible(gc())
## region area inside the composite domain (R/07's domain_km2), and inside the
## Continental window alone (aus_km2: the domain of a product without a Southern file)
gkm2 <- geo$aus$gid_km2 + geo$so$gid_km2
in_dom <- which(gkm2 > 0)
dkm2 <- rbind(data.frame(set = gid_set[in_dom], region_id = gid_region[in_dom], domain_km2 = gkm2[in_dom], aus_km2 = geo$aus$gid_km2[in_dom]),
              data.frame(set = "domain", region_id = 1L, domain_km2 = geo$aus$km2 + geo$so$km2, aus_km2 = geo$aus$km2))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
sf <- file.path(out, "screen.rds")
if (file.exists(sf)) {
  if (!identical(readRDS(sf), screen)) stop(out, " was made with another screen: use a new OUT")
} else {
  if (length(Sys.glob(file.path(out, "*", "*.rds")))) stop(out, " holds sums made before the screen: use a new OUT")
  saveRDS(screen, sf)
}
saveRDS(dkm2, file.path(out, "domain_km2.rds"))
done <- file.exists(tasks$file)
if (env("REDO_FAILED") == "1") {   # also redo months whose file logs a failed day
  failed <- vapply(seq_along(done), function(i) done[i] && any(readRDS(tasks$file[i])$days$error != ""), logical(1))
  cat("months with failed days, redone:", sum(failed), "\n")
  done <- done & !failed
}
tasks <- tasks[!done, ]
if (!nrow(tasks)) quit(save = "no")

## ---- reading (as offset.R) ---------------------------------------------------
rd <- function(f, v, W) {
  ds <- new(GDALRaster, sprintf("NETCDF:\"%s\":%s", f, v))
  on.exit(ds$close())
  nx <- ds$getRasterXSize(); ny <- ds$getRasterYSize(); gt <- ds$getGeoTransform()
  if (nx != W$ncol || ny != W$nrow) stop(sprintf("%s: %dx%d, expected %dx%d", basename(f), nx, ny, W$ncol, W$nrow))
  dx0 <- ((gt[1] - W$xmin + 180) %% 360) - 180
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
variant_x <- function(x, v) {
  if (v == "all") return(x$sst)
  y <- x$sst; y[!(is.finite(x$ql) & x$ql >= 4)] <- NA
  if (v == "q4b") y <- y - x$sb
  y
}

## ---- sums of one window-file: S2 (cells x 4), regions (G x 4), domain (4) ----
window_sums <- function(f, W) {
  sst <- rd(f, "sea_surface_temperature", W)
  fin <- is.finite(sst); if (!is.null(W$use)) fin <- fin & W$use
  k <- which(fin); rm(fin)
  s <- sst[k] - 273.15; rm(sst)
  fl <- rd(f, "l2p_flags", W)[k]
  ice <- is.finite(fl) & bitwAnd(as.integer(fl), screen$ice_bit) > 0L; rm(fl)
  oor <- !ice & (s < screen$sst_min | s > screen$sst_max)
  n0 <- length(k); n_ice <- sum(ice); n_range <- sum(oor)
  ok <- which(!(ice | oor)); rm(ice, oor)
  k <- k[ok]; s <- s[ok]
  x <- list(sst = s, ql = rd(f, "quality_level", W)[k], sb = rd(f, "sses_bias", W)[k])
  rm(s)
  rk <- W$run[k]
  L <- integer(W$N); L[k] <- seq_along(k)
  pos <- L[W$R_pix]; keep <- which(pos > 0L); pos <- pos[keep]
  gid <- W$R_gid[keep]; Rw <- W$R_w[keep]; Rnw <- W$R_nw[keep]
  rm(L, keep)
  res <- list()
  for (v in variants) {
    y <- variant_x(x, v); fy <- is.finite(y); y[!fy] <- 0
    Q <- cbind(c = as.double(fy), x = y, x2 = y * y); rm(y, fy)
    U <- rowsum(Q, rk, reorder = FALSE); runs <- as.integer(rownames(U))
    S <- matrix(0, length(kit_cells), 4)
    ss <- rowsum(cbind(U[, "c"], U * W$run_w_s2[runs]), W$run_cell[runs], reorder = FALSE)
    S[as.integer(rownames(ss)), ] <- ss
    QP <- Q[pos, , drop = FALSE]
    R <- matrix(0, G, 4)
    rg <- rowsum(cbind(QP[, "c"] * Rnw, QP * Rw), gid, reorder = FALSE)
    R[as.integer(rownames(rg)), ] <- rg
    res[[v]] <- list(S = S, R = R, D = c(sum(U[, "c"]), colSums(U * W$run_km2[runs])))
    rm(Q, U, QP)
  }
  list(res = res, n = n0, ice = n_ice, range = n_range)
}
s4 <- c("n", "sumw", "sumwx", "sumwx2")
one_day <- function(d) {
  t0 <- Sys.time()
  parts <- list()
  if (nzchar(d$path_aus)) parts$aus <- window_sums(file.path(root, d$path_aus), geo$aus)
  if (nzchar(d$path_so)) parts$so <- window_sums(file.path(root, d$path_so), geo$so)
  s2 <- reg <- list(); info <- list()
  for (v in variants) {
    S <- Reduce(`+`, lapply(parts, function(p) p$res[[v]]$S))
    R <- Reduce(`+`, lapply(parts, function(p) p$res[[v]]$R))
    D <- Reduce(`+`, lapply(parts, function(p) p$res[[v]]$D))
    ks <- which(S[, 1] > 0)
    ## rep(): a variant can have no cells at all (a near-empty night file with no
    ## quality-4 pixel), and data.frame() won't recycle a date over zero rows
    s2[[v]] <- data.frame(date = rep(d$date, length(ks)), variant = rep(v, length(ks)), cell = ks,
                          `colnames<-`(S[ks, , drop = FALSE], s4))
    reg[[v]] <- rbind(data.frame(date = d$date, variant = v, set = gid_set[in_dom], region_id = gid_region[in_dom],
                                 `colnames<-`(R[in_dom, , drop = FALSE], s4)),
                      data.frame(date = d$date, variant = v, set = "domain", region_id = 1L, `names<-`(as.list(D), s4)))
    info[[v]] <- D
  }
  nn <- function(g, k = "n") if (is.null(parts[[g]])) 0L else parts[[g]][[k]]
  list(s2 = do.call(rbind, s2), regions = do.call(rbind, reg),
       day = data.frame(date = d$date, file_aus = basename(d$path_aus), file_so = basename(d$path_so),
                        stale_aus = d$stale_aus, stale_so = d$stale_so, n_aus = nn("aus"), n_so = nn("so"),
                        ice_aus = nn("aus", "ice"), ice_so = nn("so", "ice"), range_aus = nn("aus", "range"), range_so = nn("so", "range"),
                        n_q4 = unname(info$q4[1]), mean_q4b = unname(info$q4b[3] / info$q4b[2]),
                        seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), error = ""))
}

## ---- one task = one product-month ---------------------------------------------
run_task <- function(i) {
  t <- tasks[i, ]
  P <- days[days$product == t$product & days$month == t$month, ]
  if (MAXDAYS > 0) P <- head(P, MAXDAYS)
  s2 <- reg <- log <- vector("list", nrow(P))
  for (j in seq_len(nrow(P))) {
    t0 <- Sys.time()
    r <- tryCatch(one_day(P[j, ]), error = function(e) conditionMessage(e))
    if (is.character(r)) {
      log[[j]] <- data.frame(date = P$date[j], file_aus = basename(P$path_aus[j]), file_so = basename(P$path_so[j]),
                             stale_aus = P$stale_aus[j], stale_so = P$stale_so[j], n_aus = NA_integer_, n_so = NA_integer_,
                             ice_aus = NA_integer_, ice_so = NA_integer_, range_aus = NA_integer_, range_so = NA_integer_,
                             n_q4 = NA_real_, mean_q4b = NA_real_,
                             seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), error = r)
      next
    }
    s2[[j]] <- r$s2; reg[[j]] <- r$regions; log[[j]] <- r$day
  }
  res <- list(product = t$product, month = t$month, s2 = do.call(rbind, s2), regions = do.call(rbind, reg),
              days = do.call(rbind, log), screen = screen)
  if (!is.null(res$s2)) { rownames(res$s2) <- NULL; rownames(res$regions) <- NULL }
  rownames(res$days) <- NULL
  dir.create(dirname(t$file), recursive = TRUE, showWarnings = FALSE)
  saveRDS(res, paste0(t$file, ".tmp")); file.rename(paste0(t$file, ".tmp"), t$file)
  ok <- res$days$error == ""
  sprintf("%s %s: %d/%d days, %s s/day%s", t$product, t$month, sum(ok), nrow(P), format(round(mean(res$days$seconds), 1)),
          if (any(!ok)) paste0("; error: ", res$days$error[!ok][1]) else "")
}
cat("workers:", NWORK, " tasks:", nrow(tasks), "\n")
t0 <- Sys.time()
msg <- mclapply(seq_len(nrow(tasks)), function(i) tryCatch(run_task(i), error = function(e) paste("task failed:", tasks$product[i], tasks$month[i], conditionMessage(e))),
                mc.cores = NWORK, mc.preschedule = FALSE)
for (m in msg) cat(if (is.character(m)) m else paste("worker error:", as.character(m)), "\n")
cat(sprintf("done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
