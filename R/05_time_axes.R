# Audit the time axis of every Zarr store in s3://aodn-cloud-optimised.
#
# Per store: length, whether time is strictly increasing, how many steps go
# backwards, duplicates, the median step, the gaps (> 1.5 x median) and the
# largest, plus whether every array on the time dimension has the same length
# as the time coordinate. Writes inventory/time_axes.csv.
#
# usage (from the repo root): Rscript R/05_time_axes.R
library(zaro)
options(zaro.verbose = FALSE)
stores <- sub("/$", "", sapply(strsplit(readLines("inventory/aodn-cloud-optimised_toplevel.txt"), " +"), tail, 1))
stores <- grep("\\.zarr$", stores, value = TRUE)

parse_units <- function(u) {
  m <- regmatches(u, regexec("^(\\w+) since (.+)$", u))[[1]]
  mult <- c(seconds = 1, second = 1, minutes = 60, hours = 3600, days = 86400, day = 86400)[[tolower(m[2])]]
  list(mult = mult, origin = as.POSIXct(sub("T", " ", sub("Z$", "", m[3])), tz = "UTC"))
}
audit <- function(s) {
  ds <- zaro_dataset(paste0("s3://aodn-cloud-optimised/", s), anonymous = TRUE, region = "ap-southeast-2")
  tn <- intersect(c("time", "TIME"), names(ds$arrays))[1]
  if (is.na(tn)) return(data.frame(store = s, note = "no time array"))
  m <- ds$arrays[[tn]]
  u <- parse_units(m@attributes$units)
  v <- as.numeric(zaro_read(ds, tn))
  t <- u$origin + v * u$mult
  d <- diff(v) * u$mult
  med <- median(d[d > 0])
  ## arrays whose time dimension length differs from the coordinate
  lens <- vapply(ds$arrays, function(a) {
    dn <- unlist(a@attributes[["_ARRAY_DIMENSIONS"]])
    if (is.null(dn)) dn <- a@dimension_names
    i <- match(tn, dn)
    if (is.na(i)) NA_real_ else as.numeric(a@shape[i])
  }, numeric(1))
  bad <- names(lens)[!is.na(lens) & lens != length(v)]
  data.frame(store = sub("\\.zarr$", "", s), n = length(v),
             start = format(min(t)), end = format(max(t)),
             increasing = all(d > 0), n_backwards = sum(d < 0), n_dup = sum(d == 0),
             step_median_h = med / 3600,
             n_gaps = sum(d > 1.5 * med), max_gap_d = round(max(d) / 86400, 1),
             len_mismatch = if (length(bad)) paste0(paste(bad, collapse = " "), " [", paste(unique(lens[bad]), collapse = ","), " vs ", length(v), "]") else "",
             note = "")
}
res <- lapply(stores, function(s) tryCatch(audit(s), error = function(e) data.frame(store = s, note = conditionMessage(e))))
keys <- unique(unlist(lapply(res, names)))
res <- do.call(rbind, lapply(res, function(r) { r[setdiff(keys, names(r))] <- NA; r[keys] }))
write.csv(res, "inventory/time_axes.csv", row.names = FALSE)
cat(sum(!res$increasing, na.rm = TRUE), "of", nrow(res), "stores have non-increasing time\n")
print(res[which(!res$increasing | res$len_mismatch != "" | res$note != ""),
          c("store", "n", "n_backwards", "n_dup", "max_gap_d", "len_mismatch", "note")], row.names = FALSE)
