# Read the 2024-01-04..08 block of L3S day+night SST (BoM/IMOS GHRSST L3S, the
# gappy 0.02 degree ABOM composites, not MUR) and report timing and summary
# statistics per file. The point is to compare in-situ reads on Gadi with
# THREDDS and S3 (R/07: ~9 s per variable per 5-day Australia block from the
# AODN Zarr), and IMOS's copy with BoM's.
#
# Two families of files, with different names and layouts:
#   qm43  BoM's archive: v02.0fv01 (= IMOS operational) and v02.0fv02 (BoM
#         reprocessing). On Gadi /g/data/qm43/ghrsst; anywhere
#         /vsicurl/https://thredds.nci.org.au/thredds/fileServer/qm43/ghrsst
#   imos  IMOS's copy (fv01 content, IMOS names). On Gadi
#         /g/data/sh74/IMOS_AODN/IMOS/SRS/SST/ghrsst; anywhere
#         /vsis3/imos-data/IMOS/SRS/SST/ghrsst (with AWS_NO_SIGN_REQUEST=YES, AWS_REGION=ap-southeast-2)
# Missing files are reported, not fatal. Values are decoded (scale/offset,
# nodata) by GDAL's netCDF driver; SST stats in degrees C over quality_level >= 4.
#
# usage: Rscript block_read.R [QM43_ROOT] [IMOS_ROOT] [OUT.csv] [PRODUCTS]
#   PRODUCTS: comma-separated subset of the names below (default all)
suppressPackageStartupMessages(library(gdalraster))
args <- commandArgs(TRUE)
roots <- c(qm43 = if (length(args) >= 1) args[1] else "/g/data/qm43/ghrsst",
           imos = if (length(args) >= 2) args[2] else "/g/data/sh74/IMOS_AODN/IMOS/SRS/SST/ghrsst")
out <- if (length(args) >= 3) args[3] else "block_read.csv"
set_config_option("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
set_config_option("GDAL_HTTP_TIMEOUT", "120"); set_config_option("GDAL_HTTP_MAX_RETRY", "3")

dates <- as.Date("2024-01-04") + 0:4
## family, directory, HHMMSS, name tail
prod <- list(
  cont_avhrr_fv02  = c("qm43", "v02.0fv02/Continental/L3S-01day/dn", "092000", "AVHRR_D-1d_dn-v02.0-fv02.0"),
  cont_multi_fv02  = c("qm43", "v02.0fv02/Continental/L3S-01day/dn", "092000", "MultiSensor-1d_dn-v02.0-fv02.0"),
  cont_avhrr_fv01  = c("qm43", "v02.0fv01/L3S-01day/dn", "092000", "AVHRR_D-1d_dn-v02.0-fv01.0"),
  cont_multi_fv01  = c("qm43", "v02.0fv01/L3S-01day/dn", "092000", "MultiSensor-1d_dn-v02.0-fv01.0"),
  south_avhrr_fv01 = c("qm43", "v02.0fv01/L3S-01day-Southern/dn", "111000", "AVHRR_D-1d_dn_Southern-v02.0-fv01.0"),
  south_multi_fv01 = c("qm43", "v02.0fv01/L3S-01day-Southern/dn", "111000", "MultiSensor-1d_dn_Southern-v02.0-fv01.0"),
  imos_cont_avhrr  = c("imos", "L3S-1d/dn", "092000", "AVHRR_D-1d_dn"),
  imos_cont_multi  = c("imos", "L3SM-1d/dn", "092000", "MultiSensor-1d_dn"),
  imos_south_avhrr = c("imos", "L3S-1dS/dn", "111000", "AVHRR_D-1d_dn_Southern"),
  imos_south_multi = c("imos", "L3SM-1dS/dn", "111000", "MultiSensor-1d_dn_Southern"))
if (length(args) >= 4) prod <- prod[strsplit(args[4], ",")[[1]]]

rd <- function(f, v) {
  ds <- new(GDALRaster, sprintf("NETCDF:\"%s\":%s", f, v))
  on.exit(ds$close())
  nx <- ds$getRasterXSize(); ny <- ds$getRasterYSize()
  x <- ds$read(1, 0, 0, nx, ny, nx, ny)
  nd <- ds$getNoDataValue(1); sc <- ds$getScale(1); of <- ds$getOffset(1)
  if (!is.na(nd)) x[x == nd] <- NA
  x * ifelse(is.na(sc), 1, sc) + ifelse(is.na(of), 0, of)
}
rows <- list()
for (p in names(prod)) {
  d <- prod[[p]]
  for (k in seq_along(dates)) {
    f <- sprintf("%s/%s/%s/%s%s-ABOM-L3S_GHRSST-SSTfnd-%s.nc", roots[[d[1]]], d[2], format(dates[k], "%Y"),
                 format(dates[k], "%Y%m%d"), d[3], d[4])
    t0 <- Sys.time()
    r <- tryCatch({
      sst <- rd(f, "sea_surface_temperature"); ql <- rd(f, "quality_level"); sb <- rd(f, "sses_bias")
      q4 <- is.finite(sst) & is.finite(ql) & ql >= 4
      data.frame(n_valid = sum(is.finite(sst)), n_q4 = sum(q4), mean_q4_C = mean(sst[q4]) - 273.15,
                 mean_bias_q4 = mean(sb[q4], na.rm = TRUE), error = "")
    }, error = function(e) data.frame(n_valid = NA, n_q4 = NA, mean_q4_C = NA, mean_bias_q4 = NA, error = conditionMessage(e)))
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    rows[[length(rows) + 1]] <- cbind(data.frame(product = p, family = d[1], date = dates[k], seconds_3vars = round(el, 2),
                                                 file = basename(f), root = roots[[d[1]]]), r)
    message(sprintf("%-17s %s %6.1f s  %s", p, dates[k], el, if (nzchar(r$error)) substr(r$error, 1, 60) else ""))
  }
}
res <- do.call(rbind, rows)
write.csv(res, out, row.names = FALSE)
print(aggregate(cbind(seconds_3vars, n_q4, mean_q4_C) ~ product, res, mean), row.names = FALSE)
