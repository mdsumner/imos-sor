# Check whether the IMOS 0.02 degree GHRSST grids (Australia and Southern
# Ocean domains) are one lattice, and define the union grid used for
# coverage tables.
#
# Reads only the 1-D lon/lat coordinate arrays with zaro. Writes
# boundaries/lattice.csv (one row per grid: extent as cell edges, dimension,
# offset into the union grid).
#
# usage (from the repo root): Rscript R/02_lattice.R
library(zaro)
options(zaro.verbose = FALSE)

B <- "s3://aodn-cloud-optimised/"
stores <- c(
  aus = "satellite_ghrsst_l3s_1day_daynighttime_single_sensor_australia.zarr",
  aus_multi = "satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_australia.zarr",
  so = "satellite_ghrsst_l3s_1day_daynighttime_single_sensor_southernocean.zarr",
  so_multi = "satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_southernocean.zarr",
  austemp = "satellite_austemp_sst_14day.zarr"
)
res <- 0.02
rows <- lapply(names(stores), function(nm) {
  ds <- zaro_dataset(paste0(B, stores[[nm]]), anonymous = TRUE, region = "ap-southeast-2")
  vars <- names(ds$arrays)
  ln <- intersect(c("lon", "longitude", "LONGITUDE"), vars)[1]
  lt <- intersect(c("lat", "latitude", "LATITUDE"), vars)[1]
  xy <- list(zaro_read(ds, ln), zaro_read(ds, lt))   # installed zaro has no zaro_read_arrays() yet
  x <- as.numeric(xy[[1]]); y <- as.numeric(xy[[2]])
  ## lattice phase: centres should sit at k*res + res/2 (odd hundredths)
  phase <- function(v) round(((v - res / 2) / res) - round((v - res / 2) / res), 3)
  data.frame(grid = nm, store = stores[[nm]],
             ncol = length(x), nrow = length(y),
             lat_order = if (y[2] > y[1]) "south-up" else "north-up",
             xmin = round(min(x) - res / 2, 4), xmax = round(max(x) + res / 2, 4),
             ymin = round(min(y) - res / 2, 4), ymax = round(max(y) + res / 2, 4),
             dx_maxdev = signif(max(abs(diff(x) - res)), 3),
             dy_maxdev = signif(max(abs(abs(diff(y)) - res)), 3),
             x_phase_maxdev = max(abs(phase(x))), y_phase_maxdev = max(abs(phase(y))))
})
lat <- do.call(rbind, rows)

## union of the Australia and Southern Ocean domains, as cell edges
u <- c(xmin = min(lat$xmin), xmax = max(lat$xmax), ymin = min(lat$ymin), ymax = max(lat$ymax))
union <- data.frame(grid = "union", store = "", ncol = round((u[["xmax"]] - u[["xmin"]]) / res),
                    nrow = round((u[["ymax"]] - u[["ymin"]]) / res), lat_order = "north-up",
                    xmin = u[["xmin"]], xmax = u[["xmax"]], ymin = u[["ymin"]], ymax = u[["ymax"]],
                    dx_maxdev = NA, dy_maxdev = NA, x_phase_maxdev = NA, y_phase_maxdev = NA)
lat <- rbind(lat, union)
## offsets of each grid into the union grid (0-based; rows counted from the top)
lat$col_offset <- round((lat$xmin - u[["xmin"]]) / res)
lat$row_offset <- round((u[["ymax"]] - lat$ymax) / res)
print(lat[, setdiff(names(lat), "store")], row.names = FALSE)
write.csv(lat, "boundaries/lattice.csv", row.names = FALSE)
