# Exact daily sums on finer S2 cells over one region's box (nci/fine_kit.R;
# default the STAR South-east region at S2 L8), read in situ on Gadi from
# sh74. BoM/IMOS ABOM GHRSST L3S 1-day, 0.02 degrees, not MUR.
#
# The box lies in the Continental (aus) window, where nci/sums.R's composite
# is always the Continental file. So only that file is read, and only the
# box (about 4 of a file's 9 chunks):
#   multi        = L3SM-1d/dn    MultiSensor, day+night, SSTfnd
#   single       = L3S-1d/dn     AVHRR_D, day+night, SSTfnd
#   single_night = L3S-1d/ngt    AVHRR_D, night, SSTskin
# The screen and variants are those of nci/sums.R, and OUT/screen.rds must
# match it: ice-flagged pixels (l2p_flags bit 4) and SST outside -2.5 .. 40 C
# are dropped; all = every screened SST, q4 = quality_level >= 4, q4b = q4
# and SST - sses_bias. Sums per fine cell in the trend.sst schema (w =
# cos(lat), n = pixels), so they add across days and up the S2 hierarchy:
# summed over children they give nci/sums.R's L5 cell sums (R/10 checks).
#
# Output, one file per product-month (resumable: existing files are skipped,
# unless REDO_FAILED=1 and the file logs a failed day):
#   OUT/<product>/<YYYY-MM>.rds = list(
#     s2     date, variant, cell (index into kit$tokens), n, sumw, sumwx, sumwx2   (cells with n > 0)
#     days   date, file, stale, finite pixels in the L5 cells (n), dropped as ice / out of range,
#            q4 count, seconds, error
#     screen, level, kit_made)
# plus OUT/screen.rds and OUT/kit.rds (the kit used; a different kit is refused).
#
# usage: Rscript sums_fine.R <sh74 inventory.tsv.gz> <fine_kit.rds> <OUT> [SH74_ROOT] [stale.csv]
# env:   PRODUCTS=single_night  YEARS=2020  MONTHS=2024-01  NWORK=4  MAXDAYS=n  REDO_FAILED=1
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
prods <- data.frame(product = c("multi", "single", "single_night"), dir = c("L3SM-1d/dn", "L3S-1d/dn", "L3S-1d/ngt"))
if (!is.null(split_env("PRODUCTS"))) prods <- prods[prods$product %in% split_env("PRODUCTS"), ]
variants <- c("all", "q4", "q4b")
screen <- list(ice_bit = 4L, sst_min = -2.5, sst_max = 40)   # as nci/sums.R
B <- readRDS(kit_f)
B$w_pix <- rep(B$w_row, each = B$ncol)
cat(sprintf("kit: %s %d (%s), L%d, %d cells; box %d x %d at aus col %d, row %d\n", B$set, B$region_id, B$region, B$level,
            length(B$tokens), B$ncol, B$nrow, B$xoff, B$yoff))

## ---- days from the sh74 inventory (as nci/sums.R, Continental files only) ----
inv <- read.delim(gzfile(inv_f), header = FALSE, col.names = c("path", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
re <- paste0("^IMOS/SRS/SST/ghrsst/(L3S-1d|L3SM-1d)/",
             "(dn/[0-9]{4}/[0-9]{14}-ABOM-L3S_GHRSST-SSTfnd-(AVHRR_D|MultiSensor)-1d_dn",
             "|ngt/[0-9]{4}/[0-9]{14}-ABOM-L3S_GHRSST-SSTskin-(AVHRR_D|MultiSensor)-1d_night)\\.nc$")
inv <- inv[grepl(re, inv$path) & inv$size > 0, ]
inv$dir <- sub("^IMOS/SRS/SST/ghrsst/([^/]+/[^/]+)/.*$", "\\1", inv$path)
inv$date <- as.Date(substr(basename(inv$path), 1, 8), "%Y%m%d")
inv <- merge(inv, prods, by = "dir")
inv <- inv[order(-inv$size), ]
dup <- duplicated(inv[c("dir", "date")])
if (any(dup)) message(sum(dup), " duplicate (directory, day) files; keeping the largest")
days <- inv[!dup, c("product", "date", "path")]
stale <- character()
if (nzchar(stale_f) && file.exists(stale_f)) {
  s <- read.csv(stale_f, colClasses = "character")
  stale <- s$key[s$status == "size_differs"]
}
days$stale <- days$path %in% stale
days$month <- format(days$date, "%Y-%m")
if (!is.null(split_env("YEARS"))) days <- days[format(days$date, "%Y") %in% split_env("YEARS"), ]
if (!is.null(split_env("MONTHS"))) days <- days[days$month %in% split_env("MONTHS"), ]
days <- days[order(days$product, days$date), ]
rm(inv)
cat("files:", nrow(days), " stale vs S3:", sum(days$stale), "\n")
print(do.call(rbind, lapply(split(days, days$product), function(x) data.frame(product = x$product[1], days = nrow(x),
  first = min(x$date), last = max(x$date)))), row.names = FALSE)
tasks <- unique(days[c("product", "month")])
tasks$file <- file.path(out, tasks$product, paste0(tasks$month, ".rds"))
cat("product-months:", nrow(tasks), " already done:", sum(file.exists(tasks$file)), "\n")

dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (x in list(list(f = "screen.rds", v = screen, what = "screen"),
               list(f = "kit.rds", v = B[c("set", "region_id", "level", "xoff", "yoff", "ncol", "nrow", "cell", "tokens")], what = "kit"))) {
  f <- file.path(out, x$f)
  if (file.exists(f)) { if (!identical(readRDS(f), x$v)) stop(out, " was made with another ", x$what, ": use a new OUT") }
  else { if (length(Sys.glob(file.path(out, "*", "*.rds")))) stop(out, " holds sums without ", x$f); saveRDS(x$v, f) }
}
done <- file.exists(tasks$file)
if (env("REDO_FAILED") == "1") {
  failed <- vapply(seq_along(done), function(i) done[i] && any(readRDS(tasks$file[i])$days$error != ""), logical(1))
  cat("months with failed days, redone:", sum(failed), "\n")
  done <- done & !failed
}
tasks <- tasks[!done, ]
if (!nrow(tasks)) quit(save = "no")

## ---- reading the box (as nci/sums.R's rd, for a window of the file) ----------
rd <- function(f, v) {
  A <- B$aus
  ds <- new(GDALRaster, sprintf("NETCDF:\"%s\":%s", f, v))
  on.exit(ds$close())
  nx <- ds$getRasterXSize(); ny <- ds$getRasterYSize(); gt <- ds$getGeoTransform()
  if (nx != A$ncol || ny != A$nrow) stop(sprintf("%s: %dx%d, expected %dx%d", basename(f), nx, ny, A$ncol, A$nrow))
  dx0 <- ((gt[1] - A$xmin + 180) %% 360) - 180
  south_up <- gt[6] > 0
  y0 <- if (south_up) gt[4] + ny * gt[6] else gt[4]
  if (abs(dx0) > 1e-3 || abs(y0 - A$ymax) > 1e-3 || abs(gt[2] - A$res) > 1e-6 || abs(abs(gt[6]) - A$res) > 1e-6)
    stop(sprintf("%s: geotransform %s does not fit the lattice", basename(f), paste(signif(gt, 8), collapse = " ")))
  yoff <- if (south_up) ny - (B$yoff + B$nrow) else B$yoff
  x <- ds$read(1, B$xoff, yoff, B$ncol, B$nrow, B$ncol, B$nrow)
  nd <- ds$getNoDataValue(1); sc <- ds$getScale(1); of <- ds$getOffset(1)
  if (!is.na(nd)) x[x == nd] <- NA
  x <- x * ifelse(is.na(sc), 1, sc) + ifelse(is.na(of), 0, of)
  if (south_up) x <- as.vector(matrix(x, B$ncol)[, B$nrow:1])
  x
}
variant_x <- function(x, v) {   # as nci/sums.R
  if (v == "all") return(x$sst)
  y <- x$sst; y[!(is.finite(x$ql) & x$ql >= 4)] <- NA
  if (v == "q4b") y <- y - x$sb
  y
}
s4 <- c("n", "sumw", "sumwx", "sumwx2")
one_day <- function(d) {
  t0 <- Sys.time()
  f <- file.path(root, d$path)
  sst <- rd(f, "sea_surface_temperature")
  k <- which(is.finite(sst) & B$cell > 0L)
  s <- sst[k] - 273.15; rm(sst)
  fl <- rd(f, "l2p_flags")[k]
  ice <- is.finite(fl) & bitwAnd(as.integer(fl), screen$ice_bit) > 0L; rm(fl)
  oor <- !ice & (s < screen$sst_min | s > screen$sst_max)
  n0 <- length(k); n_ice <- sum(ice); n_range <- sum(oor)
  ok <- which(!(ice | oor)); rm(ice, oor)
  k <- k[ok]; s <- s[ok]
  x <- list(sst = s, ql = rd(f, "quality_level")[k], sb = rd(f, "sses_bias")[k])
  cl <- B$cell[k]; w <- B$w_pix[k]
  s2 <- list(); nq4 <- 0
  for (v in variants) {
    y <- variant_x(x, v); j <- which(is.finite(y))
    if (v == "q4") nq4 <- length(j)
    S <- rowsum(cbind(rep(1, length(j)), w[j], w[j] * y[j], w[j] * y[j]^2), cl[j], reorder = TRUE)   # j may be empty
    s2[[v]] <- data.frame(date = rep(d$date, nrow(S)), variant = rep(v, nrow(S)), cell = as.integer(rownames(S)),
                          `colnames<-`(unname(S), s4))
  }
  list(s2 = do.call(rbind, s2),
       day = data.frame(date = d$date, file = basename(d$path), stale = d$stale, n = n0, ice = n_ice, range = n_range,
                        n_q4 = nq4, seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), error = ""))
}
run_task <- function(i) {
  t <- tasks[i, ]
  P <- days[days$product == t$product & days$month == t$month, ]
  if (MAXDAYS > 0) P <- head(P, MAXDAYS)
  s2 <- log <- vector("list", nrow(P))
  for (j in seq_len(nrow(P))) {
    t0 <- Sys.time()
    r <- tryCatch(one_day(P[j, ]), error = function(e) conditionMessage(e))
    if (is.character(r)) {
      log[[j]] <- data.frame(date = P$date[j], file = basename(P$path[j]), stale = P$stale[j], n = NA_integer_, ice = NA_integer_,
                             range = NA_integer_, n_q4 = NA_real_,
                             seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), error = r)
      next
    }
    s2[[j]] <- r$s2; log[[j]] <- r$day
  }
  res <- list(product = t$product, month = t$month, s2 = do.call(rbind, s2), days = do.call(rbind, log),
              screen = screen, level = B$level, kit_made = B$made)
  if (!is.null(res$s2)) rownames(res$s2) <- NULL
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
