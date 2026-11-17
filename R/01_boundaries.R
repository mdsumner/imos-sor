# Fetch boundary layers and build region sets.
#
# Writes data/boundaries/<set>.parquet (GeoParquet, EPSG:4326, one row per
# region with integer region_id) and boundaries/regions.csv (committed: one
# row per region with geodesic area and any published area).
#
# Region sets (each is used on its own, never mixed with another):
#   eez_legal  GA AMB2020 EEZ as amended by the Perth Treaty 1997 (GA's
#              recommended depiction), 12-200 nm, as published (9 regions)
#   eez        the same 9 territories, everything inside the 200 nm limit:
#              EEZ + territorial sea, interior holes filled (so internal
#              waters and land are included; land is masked by the data)
#   star       the six Commonwealth Marine Regions used by the STAR 2020
#              report, clipped to `eez`, plus one fill-in per territory for
#              whatever of `eez` they leave out (GBRMP, state waters,
#              Indian Ocean Territories, HIMI, AAT, ...)
#   imcra      IMCRA v4.0 provincial bioregions (41)
#   amp        Australian Marine Parks, one region per park zone (216)
#
# usage (from the repo root): Rscript R/01_boundaries.R
suppressPackageStartupMessages(library(sf))
suppressMessages(sf_use_s2(FALSE))   # planar lon/lat ops, consistent with burning on lon/lat grids
                   # (st_area still reports geodesic area via lwgeom)

out <- "data/boundaries"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dir.create("boundaries", showWarnings = FALSE)

GA <- "/vsizip//vsicurl/https://d28rz98at9flks.cloudfront.net/144571/144571_01_0.zip/Shapefiles/"
DC <- "https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/"
## GeoJSON output (always EPSG:4326) with named fields, downloaded to
## data/boundaries/raw/ first so the raw responses are kept with the build.
dir.create(file.path(out, "raw"), showWarnings = FALSE)
esri <- function(path, fields) {
  url <- sprintf("%s%s/query?where=1%%3D1&outFields=%s&outSR=4326&f=geojson", DC, path,
                 paste(fields, collapse = ","))
  f <- file.path(out, "raw", paste0(sub("/.*", "", path), ".geojson"))
  if (!file.exists(f)) download.file(url, f, quiet = TRUE, mode = "wb")
  f
}
km2 <- function(x) as.numeric(st_area(x)) / 1e6
to4326 <- function(x) st_make_valid(st_transform(x, 4326))
fill_holes <- function(g) {
  st_sfc(lapply(g, function(p) {
    if (inherits(p, "POLYGON")) st_polygon(p[1]) else st_multipolygon(lapply(p, function(pp) pp[1]))
  }), crs = st_crs(g))
}
## make a set disjoint by priority (earlier rows win), report what was trimmed
disjoint <- function(x) {
  g <- st_geometry(x)
  acc <- g[1]
  for (i in seq_along(g)[-1]) {
    gi <- st_difference(g[i], acc)
    g[i] <- if (length(gi)) st_cast(st_union(gi), "MULTIPOLYGON") else st_sfc(st_multipolygon(), crs = st_crs(g))
    acc <- st_union(acc, g[i])
  }
  st_geometry(x) <- st_cast(g, "MULTIPOLYGON")
  x
}
overlap_km2 <- function(x) sum(km2(x)) - km2(st_union(st_geometry(x)))
write_set <- function(x, set) {
  x$set <- set
  x$region_id <- seq_len(nrow(x))
  names(x)[names(x) == "AREA_KM2"] <- "published_km2"   # OGR field names are case-insensitive: AREA_KM2 vs area_km2 clash
  x$geod_km2 <- km2(x)
  x <- x[, c("set", "region_id", "region", setdiff(names(x), c("set", "region_id", "region")))]
  f <- file.path(out, paste0(set, ".parquet"))
  if (file.exists(f)) unlink(f)
  st_write(x, f, driver = "Parquet", quiet = TRUE)
  message(sprintf("%-10s %4d regions  %12.0f km2  overlap %.1f km2", set, nrow(x),
                  sum(x$geod_km2), overlap_km2(x)))
  x
}

## ---- EEZ (GA AMB2020, Perth Treaty) ---------------------------------------
eez0 <- to4326(read_sf(paste0(GA, "Exclusive_Economic_Zone_Amended_By_Perth_Treaty_1997_AMB2020_Areas.shp")))
eez0$region <- sub("^EEZ-", "", eez0$NOBJNM)
ord <- c("MLD", "TST", "CI", "CKI", "NI", "MAC", "HIMI", "AATW", "AATE")
eez0 <- eez0[match(ord, eez0$region), ]
eez_legal <- write_set(eez0[, c("region", "NAME", "MRN")], "eez_legal")

## territorial sea, assigned to the territory whose hole-filled EEZ contains it,
## else the nearest EEZ (the AAT EEZs have no hole: their inner edge is the TS limit)
ts <- to4326(read_sf(paste0(GA, "Territorial_Sea_AMB2020_Areas.shp")))
filled <- fill_holes(st_geometry(eez0))
pos <- st_point_on_surface(st_geometry(ts))
hit <- sapply(st_intersects(pos, filled), function(i) if (length(i)) i[1] else NA_integer_)
miss <- is.na(hit)
hit[miss] <- st_nearest_feature(pos[miss], st_geometry(eez0))
message("territorial sea: ", nrow(ts), " features; ", sum(miss), " assigned by nearest EEZ")
eez <- eez0[, "region"]
st_geometry(eez) <- do.call(c, lapply(seq_len(nrow(eez0)), function(i) {
  g <- st_union(c(filled[i], st_geometry(ts)[hit == i]))
  st_cast(fill_holes(st_cast(g, "MULTIPOLYGON")), "MULTIPOLYGON")
}))
eez <- disjoint(eez)   # MLD first; TST etc. trimmed where filled holes overlap
eez <- write_set(eez, "eez")
eez_all <- st_union(st_geometry(eez))

## ---- STAR 2020 regions: Commonwealth Marine Regions + fill-ins --------------
cmr <- to4326(read_sf(esri("Commonwealth_Marine_Regions/MapServer/0", c("REGION", "ENVIRON"))))
cmr <- cmr[cmr$ENVIRON == "Marine", ]
six <- aggregate(cmr[, "geometry"], list(region = cmr$REGION), function(x) x[1])
six <- st_sf(region = six$region, geometry = st_cast(st_make_valid(st_geometry(six)), "MULTIPOLYGON"))
six_out <- km2(st_difference(st_union(st_geometry(six)), eez_all))
st_geometry(six) <- st_cast(st_intersection(st_geometry(six), eez_all), "MULTIPOLYGON")
six_all <- st_union(st_geometry(six))
fill <- eez[, "region"]
fill$region <- paste0("outside regions: ", eez$region)
st_geometry(fill) <- do.call(c, lapply(st_geometry(eez), function(g) {
  d <- st_difference(st_sfc(g, crs = 4326), six_all)
  if (length(d)) st_cast(d, "MULTIPOLYGON") else st_sfc(st_multipolygon(), crs = 4326)
}))
fill <- fill[km2(fill) > 0, ]
star <- rbind(six[order(six$region), ], fill)
message(sprintf("six regions: %.0f km2 lay outside the eez set and were clipped", six_out))
star <- write_set(disjoint(star), "star")

## ---- IMCRA v4.0 provincial ---------------------------------------------------
imcra <- to4326(read_sf(esri("IMCRA_Provincial/MapServer/0", c("PB_NAME", "PB_NUM", "WATER_TYPE", "AREA_KM2"))))
imcra$region <- imcra$PB_NAME
imcra <- write_set(imcra[, c("region", "PB_NUM", "WATER_TYPE", "AREA_KM2")], "imcra")
message(sprintf("imcra: %.0f km2 outside the eez set", km2(st_difference(st_union(st_geometry(imcra)), eez_all))))

## ---- Australian Marine Parks (zones) ---------------------------------------------
amp <- to4326(read_sf(esri("Australian_Marine_Parks/FeatureServer/0", c("NETNAME", "RESNAME", "ZONENAME", "ZONEIUCN", "AREA_KM2"))))
amp$region <- paste0(amp$RESNAME, " | ", amp$ZONENAME)
amp <- amp[order(amp$NETNAME, amp$RESNAME, amp$ZONENAME), ]
amp <- write_set(amp[, c("region", "NETNAME", "RESNAME", "ZONENAME", "ZONEIUCN", "AREA_KM2")], "amp")

## ---- manifest -----------------------------------------------------------------
pub <- function(x) if ("published_km2" %in% names(x)) x$published_km2 else NA_real_
tab <- do.call(rbind, lapply(list(eez_legal, eez, star, imcra, amp), function(x) {
  data.frame(set = x$set, region_id = x$region_id, region = x$region,
             geod_km2 = round(x$geod_km2, 1), published_km2 = pub(x))
}))
write.csv(tab, "boundaries/regions.csv", row.names = FALSE)
writeLines(c(
  paste("built", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  "eez_legal, eez: GA AMB2020 https://d28rz98at9flks.cloudfront.net/144571/144571_01_0.zip (Perth Treaty EEZ + Territorial Sea areas)",
  paste("star:", DC, "Commonwealth_Marine_Regions/MapServer/0"),
  paste("imcra:", DC, "IMCRA_Provincial/MapServer/0"),
  paste("amp:", DC, "Australian_Marine_Parks/FeatureServer/0"),
  paste("GDAL", gdalraster::gdal_version()[1], "| sf", packageVersion("sf"))
), "boundaries/SOURCES.txt")
