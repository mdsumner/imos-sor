# A survey of IMOS animal tracking (AATAMS / the Animal Tracking Facility),
# from AODN's cloud-optimised Parquet on S3 (s3://aodn-cloud-optimised,
# anonymous), with DuckDB. The same data as NetCDF/CSV are under
# s3://imos-data/IMOS/AATAMS/ and on NCI in /g/data/sh74/IMOS_AODN/IMOS/AATAMS/.
#
#   satellite tags   animal_metadata_ and animal_{ctd,diag,dive,gps,haulout,
#                    summary,ssmoutputs}_satellite_relay_tagging_location_qc_
#                    {delayed,realtime}_qc: SMRU SRDL tables with state-space
#                    model locations, 2007 ->
#   CTD profiles     animal_ctd_satellite_relay_tagging_delayed_qc: Argo-style
#                    profiles (MEOP QC), 2004 ->
#   acoustic         animal_acoustic_tracking_delayed_summarised_detection_qc:
#                    hourly detections per animal and receiver station, 2007 ->
#
# Caches data/animal/{ctd_profiles,acoustic_animal_inst_year,acoustic_stations}.parquet
# (delete them to refresh; about 6 minutes) and writes, committed,
# inventory/animal_{sattag_campaigns,ctd_by_species_site,acoustic_species,acoustic_installations}.csv.
# usage (from the repo root): Rscript R/13_animal_tracking.R
suppressPackageStartupMessages(library(data.table))
con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE))
invisible(DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs; SET s3_region = 'ap-southeast-2';"))
pq <- function(ds) sprintf("read_parquet('s3://aodn-cloud-optimised/%s.parquet/**/*.parquet', hive_partitioning = true, union_by_name = true)", ds)
get <- function(sql) as.data.table(DBI::dbGetQuery(con, sql))
dir.create("data/animal", showWarnings = FALSE)
cache <- function(f, sql) { if (!file.exists(f)) DBI::dbExecute(con, sprintf("COPY (%s) TO '%s' (FORMAT parquet)", sql, f)); as.data.table(nanoparquet::read_parquet(f)) }

## ---- satellite tags: campaigns (location QC metadata) ---------------------------------
md <- rbind(get(sprintf("SELECT *, 'dm' AS stream FROM %s", pq("animal_metadata_satellite_relay_tagging_location_qc_delayed_qc"))),
            get(sprintf("SELECT *, 'nrt' AS stream FROM %s", pq("animal_metadata_satellite_relay_tagging_location_qc_realtime_qc"))), fill = TRUE)
camp <- md[, .(tags = uniqueN(device_id), first_release = min(as.Date(release_date)), last_release = max(as.Date(release_date)),
               species = paste(sort(unique(common_name)), collapse = "; "), sites = paste(sort(unique(release_site)), collapse = "; "),
               country = paste(sort(unique(state_country)), collapse = "; "), tag_types = paste(sort(unique(tag_type)), collapse = " ")),
           by = .(campaign = sattag_program, stream)][order(first_release)]
fwrite(camp, "inventory/animal_sattag_campaigns.csv")
cat(sprintf("satellite tags (location QC, 2007 ->): %d tags in %d campaigns\n", uniqueN(md$device_id), uniqueN(md$sattag_program)))
print(md[, .(tags = uniqueN(device_id), campaigns = uniqueN(sattag_program), years = paste(range(year(release_date)), collapse = "-")), by = .(common_name)][order(-tags)], row.names = FALSE)
tabs <- rbindlist(lapply(c("diag", "gps", "dive", "ctd", "haulout", "summary", "ssmoutputs"), function(k) rbindlist(lapply(c("delayed", "realtime"), function(s)
  get(sprintf("SELECT '%s' AS tab, '%s' AS stream, count(*) AS n_rows, count(DISTINCT ref) AS tags FROM %s", k, s,
              pq(sprintf("animal_%s_satellite_relay_tagging_location_qc_%s_qc", k, s))))))))
cat("\nlocation QC tables (rows, tags):\n"); print(dcast(tabs, tab ~ stream, value.var = c("n_rows", "tags")), row.names = FALSE)

## ---- CTD profiles ----------------------------------------------------------------------
p <- cache("data/animal/ctd_profiles.parquet", sprintf("SELECT PLATFORM_NUMBER, CYCLE_NUMBER, any_value(species) species, any_value(\"location\") loc,
  any_value(smru_platform_code) smru, any_value(PROJECT_NAME) project, min(JULD) juld, any_value(LATITUDE) lat, any_value(LONGITUDE) lon,
  count(*) levels, max(PRES) max_pres, count(PSAL) n_psal, count(DOXY) n_doxy, count(CHLA) n_chla, count(LIGHT) n_light, any_value(DATA_MODE) dmode
  FROM %s GROUP BY PLATFORM_NUMBER, CYCLE_NUMBER", pq("animal_ctd_satellite_relay_tagging_delayed_qc")))
p[, yr := year(juld)]
cs <- p[, .(tags = uniqueN(PLATFORM_NUMBER), profiles = .N, first = min(yr), last = max(yr), with_salinity = sum(n_psal > 0),
            with_oxygen = sum(n_doxy > 0), with_chla = sum(n_chla > 0), with_light = sum(n_light > 0), median_max_dbar = median(max_pres),
            median_lat = round(median(lat), 1), north_of_equator = sum(lat > 0)), by = .(species, site = loc)][order(-profiles)]
fwrite(cs, "inventory/animal_ctd_by_species_site.csv")
cat(sprintf("\nCTD profiles: %d from %d tags, %s .. %s; south of 60 S %.0f%%, south of 50 S %.0f%%\n", nrow(p), uniqueN(p$PLATFORM_NUMBER),
            format(min(p$juld)), format(max(p$juld)), 100 * mean(p$lat < -60), 100 * mean(p$lat < -50)))
print(cs, row.names = FALSE)

## ---- acoustic -------------------------------------------------------------------------
asum <- pq("animal_acoustic_tracking_delayed_summarised_detection_qc")
a <- cache("data/animal/acoustic_animal_inst_year.parquet", sprintf("SELECT species_scientific_name sci, species_common_name common, animal_id,
  any_value(animal_sex) sex, tag_deployment_project_name tag_project, installation_name, year(date_hour_UTC) yr, sum(nb_detections) detections,
  count(DISTINCT station_name) stations, min(date_hour_UTC) t_first, max(date_hour_UTC) t_last,
  any_value(transmitter_deployment_latitude) tlat, any_value(transmitter_deployment_longitude) tlon, any_value(transmitter_deployment_locality) locality,
  any_value(transmitter_sensor_type) sensor FROM %s GROUP BY ALL", asum))
st <- cache("data/animal/acoustic_stations.parquet", sprintf("SELECT installation_name, station_name, receiver_project_name,
  avg(receiver_deployment_latitude) lat, avg(receiver_deployment_longitude) lon, min(date_hour_UTC) t_first, max(date_hour_UTC) t_last,
  sum(nb_detections) detections, count(DISTINCT animal_id) animals FROM %s GROUP BY ALL", asum))
sp <- a[, .(animals = uniqueN(animal_id), detections = sum(detections), installations = uniqueN(installation_name), first = min(yr), last = max(yr)),
        by = .(common, sci)][order(-animals)]
fwrite(sp, "inventory/animal_acoustic_species.csv")
inst <- st[, .(stations = .N, animals = max(animals), detections = sum(detections), lat = round(mean(lat), 2), lon = round(mean(lon), 2),
               first = as.Date(min(t_first)), last = as.Date(max(t_last))), by = installation_name][order(-detections)]
fwrite(inst, "inventory/animal_acoustic_installations.csv")
cat(sprintf("\nacoustic: %d species, %d animals, %s detections (hourly sums), %d installations, %d stations, %d .. %d\n", nrow(sp), uniqueN(a$animal_id),
            format(sum(a$detections), big.mark = ","), nrow(inst), nrow(st), min(a$yr), max(a$yr)))
print(head(sp, 25), row.names = FALSE)
print(a[, .(animals = uniqueN(animal_id), detections = sum(detections)), by = yr][order(yr)], row.names = FALSE)
cat(sprintf("receiver stations south of 40 S: %d; west of 120 E: %d\n", sum(st$lat < -40, na.rm = TRUE), sum(st$lon < 120, na.rm = TRUE)))
