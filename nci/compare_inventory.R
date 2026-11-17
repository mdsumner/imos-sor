# Compare an NCI sh74 inventory (from inventory.pbs) with s3://imos-data.
#
# 1. presence and size: every S3 key under SUBDIR vs every file in the
#    inventory (same relative path)
# 2. byte identity: S3 ETags (head-object) vs the S3-style ETags computed on
#    Gadi for the sample
# Writes nci/compare-<subdir>.csv (per-directory counts) and prints a summary.
#
# usage (from the repo root, with the job outputs copied into data/nci/):
#   Rscript nci/compare_inventory.R data/nci/inventory-IMOS_SRS_SST_ghrsst.tsv.gz \
#           data/nci/etags-IMOS_SRS_SST_ghrsst.tsv IMOS/SRS/SST/ghrsst
args <- commandArgs(TRUE)
inv_f <- args[1]; etag_f <- args[2]; subdir <- sub("/$", "", args[3])
aws <- c("--no-sign-request", "--region", "ap-southeast-2")

nci <- read.delim(gzfile(inv_f), header = FALSE, col.names = c("key", "size", "mtime"), colClasses = c("character", "numeric", "numeric"))
s3l <- system2("aws", c("s3", "ls", aws, "--recursive", paste0("s3://imos-data/", subdir, "/")), stdout = TRUE)
s3 <- do.call(rbind, lapply(strsplit(trimws(s3l), " +"), function(p) data.frame(key = paste(p[-(1:3)], collapse = " "), size = as.numeric(p[3]))))
m <- merge(s3, nci, by = "key", all = TRUE, suffixes = c("_s3", "_nci"))
m$status <- with(m, ifelse(is.na(size_nci), "s3_only", ifelse(is.na(size_s3), "nci_only", ifelse(size_s3 == size_nci, "same_size", "size_differs"))))
cat("keys:", nrow(m), "\n"); print(table(m$status))
m$dir <- sub("/[^/]*$", "", m$key)
by_dir <- as.data.frame.matrix(table(m$dir, m$status))
by_dir <- cbind(dir = rownames(by_dir), by_dir)
out <- file.path("nci", paste0("compare-", gsub("/", "_", subdir), ".csv"))
write.csv(by_dir, out, row.names = FALSE)
cat("per-directory counts:", out, "\n")
print(head(by_dir[rowSums(by_dir[, setdiff(names(by_dir), c("dir", "same_size")), drop = FALSE]) > 0, ], 30), row.names = FALSE)

et <- read.delim(etag_f, header = FALSE, col.names = c("path", "size", "etag_nci"), colClasses = "character")
et$key <- sub("^.*?(IMOS/)", "\\1", et$path, perl = TRUE)
et$etag_s3 <- vapply(et$key, function(k) {
  r <- suppressWarnings(system2("aws", c("s3api", "head-object", aws, "--bucket", "imos-data", "--key", shQuote(k),
                                          "--query", "ETag", "--output", "text"), stdout = TRUE, stderr = FALSE))
  if (length(r)) gsub('"', "", r[1]) else NA_character_
}, character(1))
et$match <- et$etag_nci == et$etag_s3
cat("\nETag sample:", nrow(et), "files;", sum(et$match, na.rm = TRUE), "identical;", sum(!et$match, na.rm = TRUE),
    "differ;", sum(is.na(et$etag_s3)), "not on S3\n")
if (any(!et$match, na.rm = TRUE)) print(head(et[which(!et$match), c("key", "size", "etag_nci", "etag_s3")], 20), row.names = FALSE)
write.csv(et[c("key", "size", "etag_nci", "etag_s3", "match")], sub("\\.csv$", "-etags.csv", out), row.names = FALSE)
