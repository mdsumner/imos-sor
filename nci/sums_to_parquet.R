# Turn the in-situ sums (nci/sums.R, one rds per product-month) into R/07's
# per-day parquet layout. These are BoM/IMOS ABOM GHRSST L3S 1-day day+night
# sums, not MUR.
#   OUT/s2l5/<product>_<variant>/<date>.parquet      cell, n, sumw, sumwx, sumwx2, date
#   OUT/regions/<product>_<variant>/<date>.parquet   set, region_id, n, sumw, sumwx, sumwx2, domain_km2, date
#                                                    (plus set "domain": the whole composite)
#   OUT/days-<product>.csv                           the day log: files, stale flags, pixels per window,
#                                                    what the ice/range screen dropped, errors
# Days that failed, and days whose sh74 file S3 has since replaced ("stale"),
# are left out and listed. Give more input directories to fill them (for
# example a local run of sums.R on those days from S3): a later directory
# overrides an earlier one for the same product and day.
#
# All inputs must have been made with the same screen (OUT/screen.rds of
# sums.R); the first run, made before the screen, is refused.
#
# usage (from the repo root): Rscript nci/sums_to_parquet.R [OUT] [IN ...]
#   defaults: OUT = data/sums_imos, IN = data/nci/sums-v2
args <- commandArgs(TRUE)
out <- if (length(args) >= 1) args[1] else "data/sums_imos"
ins <- if (length(args) >= 2) args[-1] else "data/nci/sums-v2"
scr <- lapply(ins, function(d) { f <- file.path(d, "screen.rds"); if (!file.exists(f)) stop(d, " has no screen.rds (made before the screen?)"); readRDS(f) })
if (!all(vapply(scr, identical, logical(1), scr[[1]]))) stop("inputs were made with different screens")
cat("screen: ice bit", scr[[1]]$ice_bit, "; SST", scr[[1]]$sst_min, "..", scr[[1]]$sst_max, "C\n")
kit <- readRDS("data/nci/offset_kit.rds"); cells <- kit$cells
s4 <- c("n", "sumw", "sumwx", "sumwx2")
dkm2 <- readRDS(file.path(ins[1], "domain_km2.rds"))

files <- do.call(rbind, lapply(seq_along(ins), function(i) {
  f <- Sys.glob(file.path(ins[i], "*", "*.rds"))
  if (length(f)) data.frame(src = i, file = f, product = basename(dirname(f)), month = sub("\\.rds$", "", basename(f)))
}))
if (is.null(files)) stop("no sums under ", paste(ins, collapse = " "))
cat("product-month files:", nrow(files), " input directories:", length(ins), "\n")
## which source gives each product-day: the last one where the day is good
logs <- do.call(rbind, lapply(seq_len(nrow(files)), function(i) data.frame(src = files$src[i], product = files$product[i], readRDS(files$file[i])$days, row.names = NULL)))
logs$good <- logs$error == "" & !logs$stale_aus & !logs$stale_so
logs <- logs[order(logs$product, logs$date, logs$good, logs$src), ]
pick <- logs[!duplicated(logs[c("product", "date")], fromLast = TRUE), ]
use <- pick[pick$good, c("product", "date", "src")]
bad <- pick[!pick$good, ]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (p in unique(pick$product)) write.csv(pick[pick$product == p, setdiff(names(pick), "good")], file.path(out, paste0("days-", p, ".csv")), row.names = FALSE)
cat("days written:", nrow(use), " left out:", nrow(bad), "\n")
if (nrow(bad)) print(table(bad$product, ifelse(bad$error != "", "failed", "stale vs S3")))
## what the screen took, and windows it emptied (a broken file, or nothing but ice)
g <- pick[pick$good, ]
for (p in unique(g$product)) { x <- g[g$product == p, ]
  cat(sprintf("%s: screen dropped %.3f%% of finite pixels (ice %.3f%%, out of range %.3f%%)\n", p,
              100 * sum(x[c("ice_aus", "ice_so", "range_aus", "range_so")]) / sum(x[c("n_aus", "n_so")]),
              100 * sum(x[c("ice_aus", "ice_so")]) / sum(x[c("n_aus", "n_so")]),
              100 * sum(x[c("range_aus", "range_so")]) / sum(x[c("n_aus", "n_so")]))) }
for (w in c("aus", "so")) {
  e <- g[g[[paste0("n_", w)]] > 0 & g[[paste0("range_", w)]] > 0.5 * g[[paste0("n_", w)]], ]
  if (nrow(e)) { cat("windows mostly out of range (", w, "):\n", sep = ""); print(e[c("product", "date", paste0(c("n_", "range_"), w))], row.names = FALSE) }
}

n_written <- 0L
for (i in seq_len(nrow(files))) {
  r <- readRDS(files$file[i])
  u <- use[use$product == files$product[i] & use$src == files$src[i] & format(use$date, "%Y-%m") == files$month[i], ]
  if (!nrow(u)) next
  s2 <- r$s2[r$s2$date %in% u$date, ]
  reg <- r$regions[r$regions$date %in% u$date, ]
  reg <- merge(reg, dkm2, by = c("set", "region_id"), all.x = TRUE, sort = FALSE)
  for (v in unique(s2$variant)) for (d in as.character(unique(u$date))) {
    a <- s2[s2$variant == v & s2$date == as.Date(d), ]
    a <- data.frame(cell = cells[a$cell], a[s4], date = as.Date(d), row.names = NULL)
    a <- a[order(a$cell), ]
    b <- reg[reg$variant == v & reg$date == as.Date(d), ]
    b <- data.frame(set = b$set, region_id = b$region_id, b[s4], domain_km2 = b$domain_km2, date = as.Date(d), row.names = NULL)
    b <- b[order(b$set, b$region_id), ]
    for (k in c("s2l5", "regions")) {
      f <- file.path(out, k, paste0(files$product[i], "_", v), paste0(d, ".parquet"))
      dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
      nanoparquet::write_parquet(if (k == "s2l5") a else b, f)
    }
    n_written <- n_written + 2L
  }
}
cat("parquet files written:", n_written, "under", out, "\n")
