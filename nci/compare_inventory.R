# Compare an NCI sh74 inventory (from inventory.pbs) with s3://imos-data.
#
# 1. presence and size: every S3 key under SUBDIR vs every file in the
#    inventory (same relative path)
# 2. byte identity: S3 ETags vs the S3-style ETags computed on Gadi for the
#    sample (s3etag.py, 8 MiB parts)
# The S3 side is one list-objects-v2 listing (key, size, ETag, LastModified),
# made here if not given: about 15 min for the 1.3 M objects under
# IMOS/SRS/SST/ghrsst.
# Writes nci/compare-<subdir>.csv (per-directory counts, only directories with
# differences) and nci/compare-<subdir>-etags.csv (the sample), and prints a summary.
#
# usage (from the repo root):
#   Rscript nci/compare_inventory.R <inventory.tsv.gz> <etags.tsv> <SUBDIR> [s3-listing.tsv.gz]
args <- commandArgs(TRUE)
inv_f <- args[1]; etag_f <- args[2]; subdir <- sub("/$", "", args[3])
s3_f <- if (length(args) >= 4) args[4] else file.path(dirname(inv_f), paste0("s3-", gsub("/", "_", subdir), ".tsv.gz"))
if (!file.exists(s3_f)) {
  message("listing s3://imos-data/", subdir, "/ into ", s3_f)
  cmd <- sprintf("aws s3api list-objects-v2 --no-sign-request --region ap-southeast-2 --bucket imos-data --prefix %s/ --query 'Contents[].[Key,Size,ETag,LastModified]' --output text | gzip > %s",
                 shQuote(subdir), shQuote(s3_f))
  stopifnot(system(cmd) == 0)
}
s3 <- read.delim(gzfile(s3_f), header = FALSE, col.names = c("key", "size", "etag", "modified"),
                 colClasses = c("character", "numeric", "character", "character"), quote = "")
s3$etag <- gsub('"', "", s3$etag)
nci <- read.delim(gzfile(inv_f), header = FALSE, col.names = c("key", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
cat("S3 objects:", nrow(s3), " NCI files:", nrow(nci), "\n")
m <- merge(s3[c("key", "size", "modified")], nci[c("key", "size", "mtime")], by = "key", all = TRUE, suffixes = c("_s3", "_nci"))
m$status <- with(m, ifelse(is.na(size_nci), "s3_only", ifelse(is.na(size_s3), "nci_only",
                     ifelse(size_s3 == size_nci, "same_size", "size_differs"))))
print(table(m$status))
m$dir <- sub("/[^/]*$", "", m$key)
by_dir <- as.data.frame.matrix(table(m$dir, m$status))
by_dir <- cbind(dir = rownames(by_dir), by_dir)
other <- setdiff(names(by_dir), c("dir", "same_size"))
diffs <- by_dir[rowSums(by_dir[, other, drop = FALSE]) > 0, ]
out <- file.path("nci", paste0("compare-", gsub("/", "_", subdir), ".csv"))
write.csv(diffs, out, row.names = FALSE)
cat("directories with any difference:", nrow(diffs), "of", nrow(by_dir), "->", out, "\n")
print(head(diffs, 30), row.names = FALSE)
odd <- m[m$status != "same_size", c("key", "status", "size_s3", "size_nci", "modified", "mtime")]
odd$mtime <- format(as.POSIXct(odd$mtime, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
write.csv(odd, sub("\\.csv$", "-files.csv", out), row.names = FALSE)

## etags file: path, size, then one ETag (old s3etag.py) or md5 + 8/15/16 MiB
## candidates (current s3etag.py: objects were uploaded by single PUT, 15 MiB
## s3cmd parts or 8 MiB aws-cli parts)
et <- read.delim(etag_f, header = FALSE, colClasses = "character", quote = "")
names(et)[1:2] <- c("path", "size")
cand <- as.matrix(et[, -(1:2), drop = FALSE])
et$key <- sub("^.*?(IMOS/)", "\\1", et$path, perl = TRUE)
et$etag_s3 <- s3$etag[match(et$key, s3$key)]
et$etag_nci <- apply(cand, 1, paste, collapse = " ")
et$match <- vapply(seq_len(nrow(et)), function(i) et$etag_s3[i] %in% cand[i, ], logical(1))
et$match[is.na(et$etag_s3)] <- NA
cat("\nETag sample:", nrow(et), "files;", sum(et$match, na.rm = TRUE), "identical;", sum(!et$match, na.rm = TRUE),
    "differ;", sum(is.na(et$etag_s3)), "not on S3\n")
if (any(!et$match, na.rm = TRUE)) print(head(et[which(!et$match), c("key", "size", "etag_nci", "etag_s3")], 20), row.names = FALSE)
write.csv(et[c("key", "size", "etag_nci", "etag_s3", "match")], sub("\\.csv$", "-etags.csv", out), row.names = FALSE)
