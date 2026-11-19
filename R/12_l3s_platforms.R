# Platforms and processing inputs of the IMOS single-sensor L3S record,
# night (L3S-1d/ngt) and day+night (L3S-1d/dn), from the files' global
# attributes (BoM/IMOS ABOM GHRSST L3S, AVHRR HRPT; not MUR).
#
# Night: read here from the public S3 bucket with GDAL's netCDF driver
# (header reads only), cached in data/nci/headers-l3s1d-ngt.tsv.gz, about
# 35 minutes the first time. Day+night: nci/headers.pbs's table from Gadi,
# data/nci/headers-l3s1d.tsv.gz (the IMOS copy in sh74).
#
# For each product, runs of consecutive days with the same value of:
#   platforms   the L3C inputs (`source`: l3_source), e.g. AVHRR18_D+AVHRR19_D
#   ice, wind, analysis   the ice, wind and reference-analysis sources
#   version     product_version (2 = BoM fv02 reprocessing, 1 = fv01)
# and the median UTC start and stop of each year's files.
#
# Writes, committed, inventory/l3s1d_processing_runs.csv and
# inventory/l3s1d_time_window_by_year.csv.
# usage (from the repo root): Rscript R/12_l3s_platforms.R
suppressPackageStartupMessages({ library(data.table); library(parallel) })
ngt_f <- "data/nci/headers-l3s1d-ngt.tsv.gz"; dn_f <- "data/nci/headers-l3s1d.tsv.gz"
stopifnot(file.exists(dn_f))

## ---- night headers from S3 (once) --------------------------------------------------
if (!file.exists(ngt_f)) {
  Sys.setenv(AWS_NO_SIGN_REQUEST = "YES", AWS_REGION = "ap-southeast-2", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
  keys <- fread(cmd = "zcat data/nci/s3-IMOS_SRS_SST_ghrsst.tsv.gz", header = FALSE, sep = "\t", select = 1L)[[1]]
  keys <- sort(grep("^IMOS/SRS/SST/ghrsst/L3S-1d/ngt/[0-9]{4}/.*\\.nc$", keys, value = TRUE))
  cat("night files in the S3 inventory:", length(keys), "\n")
  att <- c("uuid", "id", "product_version", "date_created", "start_time", "stop_time", "platform", "sensor", "source", "history")
  one <- function(k) tryCatch({
    ds <- new(gdalraster::GDALRaster, sprintf('NETCDF:"/vsis3/imos-data/%s":sea_surface_temperature', k))
    md <- ds$getMetadata(band = 0, domain = ""); ds$close()
    md <- md[startsWith(md, "NC_GLOBAL#")]
    nm <- sub("=.*", "", sub("^NC_GLOBAL#", "", md)); val <- sub("^[^=]*=", "", md)
    as.list(c(path = k, setNames(val[match(att, nm)], att)))
  }, error = function(e) list(path = k, uuid = "ERROR"))
  t0 <- Sys.time()
  h <- rbindlist(mclapply(keys, one, mc.cores = 16L, mc.preschedule = FALSE), fill = TRUE)
  cat(sprintf("%d rows, %d errors, %.0f s\n", nrow(h), sum(h$uuid == "ERROR", na.rm = TRUE), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  fwrite(h, ngt_f, sep = "\t")
}

## ---- both products --------------------------------------------------------------------
kv <- function(s, k) { out <- rep(NA_character_, length(s)); j <- grepl(paste0(k, "="), s)
  out[j] <- sub(".*=", "", regmatches(s[j], regexpr(paste0(k, "=[^,]*"), s[j]))); out }
plats_of <- function(src) vapply(strsplit(sub(".*l3_source=", "", src), ";"), function(x) paste(sort(sub("-ABOM-L3C.*", "", x)), collapse = "+"), "")
hr <- function(x, d) as.numeric(difftime(as.POSIXct(x, format = "%Y%m%dT%H%M%SZ", tz = "UTC"), as.POSIXct(paste(d, "00:00:00"), tz = "UTC"), units = "hours"))
ngt <- fread(ngt_f, sep = "\t")[uuid != "ERROR"]
dn <- fread(dn_f, sep = "\t", quote = "", fill = TRUE)[grepl("/IMOS/SRS/SST/ghrsst/L3S-1d/dn/", path) & uuid != "ERROR"]
h <- rbind(ngt[, .(product = "single_night", path, product_version, start_time, stop_time, source)],
           dn[, .(product = "single", path, product_version, start_time, stop_time, source)])
h[, date := as.Date(substr(basename(path), 1, 8), "%Y%m%d")]
setorder(h, product, date)
h[, `:=`(platforms = plats_of(source), ice = kv(source, "ice_source"), wind = kv(source, "wind_source"),
         analysis = kv(source, "analysis_source"), version = as.character(as.numeric(product_version)))]
cat("files:", paste(h[, .N, by = product][, sprintf("%s %d", product, N)], collapse = ", "), "\n")

runs <- rbindlist(lapply(c("platforms", "ice", "wind", "analysis", "version"), function(k) h[, {
  r <- rle(get(k)); e <- cumsum(r$lengths); s <- e - r$lengths + 1L
  .(attribute = k, value = r$values, from = date[s], to = date[e], days = r$lengths)
}, by = product]))
fwrite(runs, "inventory/l3s1d_processing_runs.csv")
win <- h[, .(files = .N, start_utc_h = round(median(hr(start_time, date)), 2), stop_utc_h = round(median(hr(stop_time, date)), 2)), by = .(product, year = year(date))]
fwrite(win, "inventory/l3s1d_time_window_by_year.csv")

## ---- print ----------------------------------------------------------------------------
cat("\nruns of 15 days or more (platforms) and 30 or more (the rest), from 2008:\n")
print(runs[to >= as.Date("2008-01-01") & days >= fifelse(attribute == "platforms", 15L, 30L)][order(attribute, product, from)], nrows = 200)
same <- merge(h[product == "single_night", .(date, p_ngt = platforms)], h[product == "single", .(date, p_dn = platforms)], by = "date")
cat(sprintf("\nsame platforms on the same day, night vs day+night: %d of %d days; differ on %s\n", sum(same$p_ngt == same$p_dn), nrow(same),
            paste(format(head(same[p_ngt != p_dn, date], 10)), collapse = " ")))
cat("\nmedian UTC hours of the files' start and stop, by year:\n")
print(dcast(win[year >= 2008], year ~ product, value.var = c("start_utc_h", "stop_utc_h")), row.names = FALSE)
