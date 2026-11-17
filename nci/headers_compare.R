# Which BoM file is each IMOS L3S file? Decided from headers (headers.pbs).
#
# BoM/IMOS ABOM GHRSST L3S 1-day day+night (not MUR). Every BoM file has its
# own global `uuid`; IMOS keeps it when it renames the file and edits
# attributes. So the qm43 file with the same uuid is the IMOS file's source,
# and its directory says which BoM version it is: v02.0fv01 (operational,
# product_version 01.0; RT/ = real-time) or v02.0fv02 (reprocessing, 02.0).
# Where no uuid matches, the same-day qm43 file with the same
# sea_surface_temperature:add_offset (computed from the data) is reported.
# This checks the size-based guess (imos_vs_qm43.R) file by file.
#
# Writes (committed):
#   nci/imos_vs_qm43_headers_by_year.csv  per IMOS product x year: source version
#     by uuid, IMOS product_version values, date_created range, agreement with sizes
#   nci/qm43_headers_by_year.csv          per qm43 domain x sensor x version x year:
#     product_version, netCDF library, date_created range (when BoM made the files)
#
# usage (from the repo root): Rscript nci/headers_compare.R [data/nci/headers-l3s1d.tsv.gz]
args <- commandArgs(TRUE)
f <- if (length(args)) args[1] else "data/nci/headers-l3s1d.tsv.gz"
h <- read.delim(gzfile(f), colClasses = "character", quote = "", fill = TRUE, na.strings = "NA")
err <- h$uuid %in% "ERROR" & (is.na(h$id) | h$id == "")
cat("files:", nrow(h), " unreadable by ncdump:", sum(err), "\n")
if (any(err)) print(h$path[err])
h <- h[!err, ]
## a few files carry a placeholder (uuid = "yes"): treat anything that is not a uuid as missing
bad <- !grepl("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", h$uuid)
cat("files whose uuid is not a uuid:", sum(bad), "\n")
if (any(bad)) {
  w <- ifelse(grepl("/sh74/", h$path[bad]), "imos", sub("^.*/(v02\\.0fv0[12])/.*$", "\\1", h$path[bad]))
  print(table(paste(w, ifelse(is.na(h$uuid[bad]), "<absent>", h$uuid[bad])), substr(basename(h$path[bad]), 1, 4)))
}
h$uuid[bad] <- NA

h$src <- ifelse(grepl("/sh74/", h$path), "imos", "qm43")
h$file <- basename(h$path)
h$date <- as.Date(substr(h$file, 1, 8), "%Y%m%d")
h$year <- format(h$date, "%Y")
h$domain <- ifelse(grepl("_Southern", h$file), "Southern", "Continental")
h$sensor <- sub("^.*-SSTfnd-(.*)-1d_dn.*$", "\\1", h$file)
h$version <- ifelse(h$src == "imos", NA,
                    paste0(sub(".*-(fv0[12])\\.0\\.nc$", "\\1", h$file), ifelse(grepl("/RT/", h$path), "_RT", "")))
h$imos_dir <- ifelse(h$src == "imos", sub("^.*/ghrsst/(.*)/[0-9]{4}/[^/]*$", "\\1", h$path), NA)
h$created <- as.POSIXct(h$date_created, format = "%Y%m%dT%H%M%SZ", tz = "UTC")
im <- h[h$src == "imos", ]; qm <- h[h$src == "qm43", ]
cat("IMOS:", nrow(im), " qm43:", nrow(qm), "\n")

## qm43 by itself: does the directory version agree with product_version?
cat("\nqm43 file version vs header product_version:\n"); print(table(qm$version, qm$product_version, useNA = "ifany"))
du <- qm$uuid[duplicated(qm$uuid) & !is.na(qm$uuid)]
cat("qm43 uuids held by more than one file:", length(unique(du)), "\n")
if (length(du)) print(head(qm[qm$uuid %in% du, c("path", "uuid")][order(qm$uuid[qm$uuid %in% du]), ], 10), row.names = FALSE)

## IMOS -> qm43 by uuid, else by same day + same SST add_offset
key <- function(d) paste(d$domain, d$sensor, d$date)
by_uuid <- split(qm[c("version", "date", "sst_add_offset")], qm$uuid)   # split drops NA uuids
by_day <- split(qm[c("version", "sst_add_offset")], key(qm))
im$source <- vapply(seq_len(nrow(im)), function(i) {
  q <- if (is.na(im$uuid[i])) NULL else by_uuid[[im$uuid[i]]]
  if (!is.null(q)) return(paste(sort(unique(q$version)), collapse = "+"))
  q <- by_day[[key(im[i, ])]]
  if (is.null(q)) return("absent_from_qm43")
  q <- q[q$sst_add_offset %in% im$sst_add_offset[i], ]
  if (nrow(q)) paste0("offset:", paste(sort(unique(q$version)), collapse = "+")) else "no_match"
}, character(1))
## uuid matches should also agree in date and data fingerprint
ok <- vapply(seq_len(nrow(im)), function(i) {
  q <- if (is.na(im$uuid[i])) NULL else by_uuid[[im$uuid[i]]]; if (is.null(q)) return(NA)
  all(q$date == im$date[i]) && all(q$sst_add_offset == im$sst_add_offset[i])
}, logical(1))
cat("\nuuid matches with a different date or SST add_offset:", sum(!ok, na.rm = TRUE), "of", sum(!is.na(ok)), "\n")
cat("\nIMOS source by header:\n"); print(table(im$imos_dir, im$source))
cat("\nIMOS source vs IMOS product_version:\n"); print(table(im$source, im$product_version, useNA = "ifany"))

## agreement with the size-based guess
sz_f <- "data/nci/imos_vs_qm43_files.csv.gz"
if (file.exists(sz_f)) {
  sz <- read.csv(gzfile(sz_f), colClasses = "character")
  im$size_guess <- sz$match[match(sub("^.*/(IMOS/SRS/)", "\\1", im$path), sz$path)]
  cat("\nheader source (rows) vs size-based guess (columns):\n"); print(table(im$source, im$size_guess, useNA = "ifany"))
} else im$size_guess <- NA

## per IMOS product x year
rng <- function(x) if (all(is.na(x))) NA_character_ else paste(format(range(x, na.rm = TRUE), "%Y-%m-%d"), collapse = "..")
yk <- paste(im$imos_dir, im$year, sep = "|")
tab <- as.data.frame.matrix(table(yk, im$source))
tab <- cbind(do.call(rbind, strsplit(rownames(tab), "|", fixed = TRUE)), tab)
names(tab)[1:2] <- c("imos_dir", "year")
tab$product_version <- tapply(im$product_version, yk, function(x) paste(sort(unique(x)), collapse = " "))[rownames(tab)]
tab$imos_date_created <- tapply(im$created, yk, rng)[rownames(tab)]
tab$agree_with_size <- tapply(im$source == im$size_guess, yk, function(x) sum(x, na.rm = TRUE))[rownames(tab)]
tab <- tab[order(tab$imos_dir, tab$year), ]
write.csv(tab, "nci/imos_vs_qm43_headers_by_year.csv", row.names = FALSE)
print(tab, row.names = FALSE)

## the seam per product, by uuid
cat("\n")
for (d in sort(unique(im$imos_dir))) {
  x <- im[im$imos_dir == d, ]
  f2 <- x$date[x$source == "fv02"]; f1 <- x$date[x$source %in% c("fv01", "fv01_RT", "fv01+fv01_RT")]
  cat(sprintf("%-12s fv02 %s..%s (%d) | fv01 %s..%s (%d) | fv01 days before the last fv02 day: %d\n", d,
              if (length(f2)) min(f2) else NA, if (length(f2)) max(f2) else NA, length(f2),
              if (length(f1)) min(f1) else NA, if (length(f1)) max(f1) else NA, length(f1),
              if (length(f1) && length(f2)) sum(f1 < max(f2)) else 0L))
}

## qm43 per domain x sensor x version x year: when BoM made the files
qk <- paste(qm$domain, qm$sensor, qm$version, qm$year, sep = "|")
qt <- data.frame(do.call(rbind, strsplit(sort(unique(qk)), "|", fixed = TRUE)))
names(qt) <- c("domain", "sensor", "version", "year")
s <- sort(unique(qk))
qt$files <- as.integer(table(qk)[s])
qt$product_version <- tapply(qm$product_version, qk, function(x) paste(sort(unique(x)), collapse = " "))[s]
qt$netcdf_version_id <- tapply(qm$netcdf_version_id, qk, function(x) paste(sort(unique(x)), collapse = " "))[s]
qt$date_created <- tapply(qm$created, qk, rng)[s]
write.csv(qt, "nci/qm43_headers_by_year.csv", row.names = FALSE)
cat("\nqm43 date_created by version (all years):\n")
print(do.call(rbind, lapply(split(qm, qm$version), function(x) data.frame(version = x$version[1], files = nrow(x), created = rng(x$created)))), row.names = FALSE)
