# Which BoM file version does each IMOS L3S file correspond to?
#
# IMOS's 1-day day+night L3S files (BoM ABOM GHRSST L3S, not MUR) are renamed
# copies of BoM files. qm43 holds both BoM versions: v02.0fv01 (operational)
# and v02.0fv02 (reprocessing). Compressed netCDF sizes almost never
# coincide, and IMOS only edits headers in place (Conventions, acknowledgment,
# one time attribute: about +1 KB, with arrays, chunking and compression
# unchanged). So the nearest-sized qm43 file of the same day, within TOL
# bytes, identifies the version of each IMOS day. That needs both inventories
# from Gadi and no file reads. fv01 and fv02 files of one day differ by MBs.
# Confirm with headers (product_version, date_created) before relying on it.
#
# Writes nci/imos_vs_qm43_by_year.csv (committed): per IMOS product and year,
# days matching fv02, fv01, fv01 real-time (RT/), both, neither, and IMOS days
# absent from qm43; plus the qm43 days IMOS lacks.
#
# usage (from the repo root): Rscript nci/imos_vs_qm43.R
rd <- function(f) {
  x <- read.delim(gzfile(f), header = FALSE, col.names = c("path", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
  x[grepl("\\.nc$", x$path), ]
}
imos <- rd("data/nci/inventory-sh74_IMOS_AODN_IMOS_SRS_SST_ghrsst.tsv.gz")
qm <- rd("data/nci/inventory-qm43_ghrsst.tsv.gz")

prod <- data.frame(imos_dir = c("L3S-1d/dn", "L3SM-1d/dn", "L3S-1dS/dn", "L3SM-1dS/dn"),
                   domain = c("Continental", "Continental", "Southern", "Southern"),
                   sensor = c("AVHRR_D", "MultiSensor", "AVHRR_D", "MultiSensor"))
imos$dir <- sub("^IMOS/SRS/SST/ghrsst/", "", sub("/[0-9]{4}/[^/]*$", "", imos$path))
imos <- imos[imos$dir %in% prod$imos_dir, ]
imos <- merge(imos, prod, by.x = "dir", by.y = "imos_dir")
imos$date <- as.Date(substr(basename(imos$path), 1, 8), "%Y%m%d")

b <- basename(qm$path)
l3s <- grepl("-ABOM-L3S_GHRSST-SSTfnd-.*-1d_dn(_Southern)?-v02\\.0-fv0[12]\\.0\\.nc$", b) & grepl("/dn/", qm$path)
qm <- qm[l3s, ]; b <- b[l3s]
qm$date <- as.Date(substr(b, 1, 8), "%Y%m%d")
qm$domain <- ifelse(grepl("_Southern-", b), "Southern", "Continental")
qm$sensor <- sub("^.*-SSTfnd-(.*)-1d_dn.*$", "\\1", b)
qm$version <- paste0(sub(".*-(fv0[12])\\.0\\.nc$", "\\1", b), ifelse(grepl("/RT/", qm$path), "_RT", ""))

key <- function(d) paste(d$domain, d$sensor, d$date, sep = "|")
TOL <- 16384   # bytes
qk <- split(qm[c("version", "size")], key(qm))
imos$match <- vapply(seq_len(nrow(imos)), function(i) {
  q <- qk[[key(imos[i, ])]]
  if (is.null(q)) return("absent_from_qm43")
  dd <- abs(q$size - imos$size[i])
  if (min(dd) > TOL) return("neither")
  paste(sort(unique(q$version[dd == min(dd)])), collapse = "+")
}, character(1))
imos$delta <- vapply(seq_len(nrow(imos)), function(i) {
  q <- qk[[key(imos[i, ])]]; if (is.null(q)) return(NA_real_)
  dd <- imos$size[i] - q$size; dd[which.min(abs(dd))]
}, numeric(1))
cat("size delta IMOS - nearest qm43 (bytes), matched files:\n"); print(summary(imos$delta[imos$match != "neither" & imos$match != "absent_from_qm43"]))
imos$year <- format(imos$date, "%Y")
tab <- as.data.frame.matrix(table(paste(imos$dir, imos$year, sep = "|"), imos$match))
tab <- cbind(do.call(rbind, strsplit(rownames(tab), "|", fixed = TRUE)), tab)
names(tab)[1:2] <- c("imos_dir", "year")
## qm43 days (non-RT) that IMOS lacks, per product-year
qm$imos_dir <- prod$imos_dir[match(paste(qm$domain, qm$sensor), paste(prod$domain, prod$sensor))]
have <- unique(paste(imos$dir, imos$date))
miss <- qm[!grepl("_RT$", qm$version) & !(paste(qm$imos_dir, qm$date) %in% have), ]
mt <- table(paste(miss$imos_dir, format(miss$date, "%Y"), sep = "|"))
tab$qm43_days_imos_lacks <- as.integer(mt[paste(tab$imos_dir, tab$year, sep = "|")])
tab$qm43_days_imos_lacks[is.na(tab$qm43_days_imos_lacks)] <- 0L
tab <- tab[order(tab$imos_dir, tab$year), ]
write.csv(tab, "nci/imos_vs_qm43_by_year.csv", row.names = FALSE)
print(tab, row.names = FALSE)
cat("\noverall:\n"); print(table(imos$dir, imos$match))
## the version boundary in IMOS, per product: last fv02-matched day and first fv01-matched day
for (d in prod$imos_dir) {
  x <- imos[imos$dir == d, ]
  f2 <- x$date[grepl("fv02", x$match) & !grepl("fv01", x$match)]; f1 <- x$date[grepl("fv01", x$match) & !grepl("fv02", x$match)]
  cat(sprintf("%-12s fv02-only %s..%s | fv01-only %s..%s\n", d,
              if (length(f2)) min(f2) else NA, if (length(f2)) max(f2) else NA,
              if (length(f1)) min(f1) else NA, if (length(f1)) max(f1) else NA))
}
