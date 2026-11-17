# aodn-cloud-optimised: Parquet datasets

70 hive-partitioned datasets, 157.8 GB total, harvested 2026-11-17 by scripts/parquet_inventory.py. Every dataset is also partitioned by `polygon=` (WKB hex of a spatial bounding polygon) and most by `timestamp=` (epoch seconds, year bins).


## aggregated

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| aggregated_amsa_nonqc | 334 | 6.07 | 16 | n=15 |  |
| aggregated_dugong_nonqc | 27 | 0.00 | 19 | n=27 |  |
| aggregated_kelp_nonqc | 19 | 0.00 | 22 | n=19 |  |
| aggregated_seabird_nonqc | 102 | 0.01 | 57 | n=59 |  |
| aggregated_seagrass_nonqc | 42 | 0.26 | 23 | n=42 |  |

## animal

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| animal_acoustic_tracking_delayed_detection_qc | 57041 | 1.65 | 56 | n=213 |  |
| animal_acoustic_tracking_delayed_summarised_detection_qc | 11541 | 0.30 | 29 | n=226 |  |
| animal_ctd_satellite_relay_tagging_delayed_qc | 5044 | 1.31 | 69 | n=21 | PLATFORM_NUMBER n=551 |
| animal_ctd_satellite_relay_tagging_location_qc_delayed_qc | 320 | 0.08 | 39 | n=18 |  |
| animal_ctd_satellite_relay_tagging_location_qc_realtime_qc | 31 | 0.01 | 39 | n=2 |  |
| animal_diag_satellite_relay_tagging_location_qc_delayed_qc | 604 | 0.23 | 36 | n=20 |  |
| animal_diag_satellite_relay_tagging_location_qc_realtime_qc | 28 | 0.02 | 36 | n=2 |  |
| animal_dive_satellite_relay_tagging_location_qc_delayed_qc | 338 | 0.45 | 112 | n=19 |  |
| animal_dive_satellite_relay_tagging_location_qc_realtime_qc | 25 | 0.02 | 112 | n=2 |  |
| animal_gps_satellite_relay_tagging_location_qc_delayed_qc | 12 | 0.00 | 33 | n=4 |  |
| animal_gps_satellite_relay_tagging_location_qc_realtime_qc | 3 | 0.00 | 33 | n=1 |  |
| animal_haulout_satellite_relay_tagging_location_qc_delayed_qc | 331 | 0.01 | 26 | n=20 |  |
| animal_haulout_satellite_relay_tagging_location_qc_realtime_qc | 24 | 0.00 | 26 | n=2 |  |
| animal_metadata_satellite_relay_tagging_location_qc_delayed_qc | 102 | 0.00 | 26 | n=62 |  |
| animal_metadata_satellite_relay_tagging_location_qc_realtime_qc | 6 | 0.00 | 26 | n=4 |  |
| animal_ssmoutputs_satellite_relay_tagging_location_qc_delayed_qc | 367 | 0.03 | 16 | n=19 |  |
| animal_ssmoutputs_satellite_relay_tagging_location_qc_realtime_qc | 26 | 0.00 | 16 | n=2 |  |
| animal_summary_satellite_relay_tagging_location_qc_delayed_qc | 375 | 0.03 | 59 | n=19 |  |
| animal_summary_satellite_relay_tagging_location_qc_realtime_qc | 26 | 0.00 | 59 | n=2 |  |

## argo.parquet

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| argo | 305849 | 31.91 | 64 | n=30 | PLATFORM_NUMBER n=20698 |

## autonomous

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| autonomous_underwater_vehicle | 1518 | 0.42 | 10 | n=17 | campaign_name n=68; dive_name n=873 |

## diver

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| diver_benthic_cover_in_situ_qc | 95 | 0.01 | 30 | n=34 |  |
| diver_cryptobenthic_fish_abundance_qc | 442 | 0.01 | 31 | n=35 |  |
| diver_mobile_macroinvertebrate_abundance_qc | 444 | 0.01 | 31 | n=35 |  |
| diver_off_transect_species_observations_qc | 330 | 0.00 | 31 | n=21 |  |
| diver_photoquadrat_qc_DwC | 19 | 0.00 | 26 | n=19 |  |
| diver_photoquadrat_score_qc | 260 | 0.00 | 27 | n=21 |  |
| diver_reef_fish_abundance_biomass_qc | 445 | 0.03 | 31 | n=35 |  |
| diver_site_information_qc | 93 | 0.00 | 15 |  |  |
| diver_survey_metadata_qc | 445 | 0.01 | 29 | n=35 |  |

## mooring

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| mooring_acidification_delayed_qc | 139 | 0.02 | 29 | n=18 | site_code n=4 |
| mooring_acidification_realtime_qc | 3 | 0.00 | 24 | n=1 | site_code n=3 |
| mooring_ctd_delayed_qc | 2592 | 3.96 | 18 | n=72 | site_code n=46 |
| mooring_estuarine_coastal_water_quality_monitoring_realtime_qc | 39 | 0.01 | 46 | n=2 | site_code n=9 |
| mooring_hourly_timeseries_delayed_qc | 3738 | 4.35 | 93 | n=83 | site_code n=84 |
| mooring_satellite_altimetry_calibration_validation | 249 | 0.17 | 19 | n=16 | site_code n=6; instrument n=4 |
| mooring_southern_ocean_surface_fluxes_realtime_qc | 3647 | 0.05 | 45 | n=16 |  |
| mooring_southern_ocean_surface_properties_realtime_qc | 4407 | 0.09 | 71 | n=16 |  |
| mooring_temperature_logger_delayed_qc | 26149 | 33.07 | 14 | n=86 | site_code n=53 |
| mooring_timeseries_realtime_qc | 26 | 0.00 | 17 | n=3 | site_code n=3 |

## ocean

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| ocean_glider_delayed_qc | 652 | 46.44 | 106 | n=19 | deployment_code n=436 |
| ocean_glider_realtime_nonqc | 11 | 0.04 | 106 | n=1 | deployment_code n=9 |

## station

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| station_lucinda_jetty_daily_wetlabs_ecotriplet | 2023 | 0.05 | 21 | n=11 |  |
| station_lucinda_jetty_daily_wetlabs_wqm | 3439 | 0.44 | 76 | n=11 |  |
| station_lucinda_jetty_hourly_wetlabs_ecotriplet | 44331 | 1.70 | 11 | n=10 |  |
| station_lucinda_jetty_hourly_wetlabs_wqm | 39929 | 5.83 | 33 | n=10 |  |
| station_nrs_wireless_sensor_network_realtime_qc | 15374 | 0.80 | 85 | n=17 | site_code n=3; aims_channel_id n=202 |
| station_wireless_sensor_network_delayec_qc | 22294 | 1.43 | 49 | n=16 | site_code n=39; aims_channel_id n=280 |

## vessel

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| vessel_air_sea_flux_product_delayed | 11999 | 0.53 | 96 | n=19 | platform_code n=5 |
| vessel_air_sea_flux_sst_meteo_realtime | 17724 | 2.53 | 88 | n=19 | platform_code n=5 |
| vessel_bio_optical_absorption_delayed_qc | 736 | 0.03 | 12 | n=28 |  |
| vessel_bio_optical_backscattering_delayed_qc | 92 | 0.00 | 9 | n=7 |  |
| vessel_bio_optical_pigment_delayed_qc | 928 | 0.02 | 58 | n=38 |  |
| vessel_bio_optical_suspended_matter_delayed_qc | 329 | 0.00 | 9 | n=29 |  |
| vessel_co2_delayed_qc | 2879 | 0.25 | 41 | n=195 | platform_code n=7 |
| vessel_co2_realtime_nonqc | 758 | 0.05 | 27 | n=25 | platform_code n=1 |
| vessel_ctd_profiles_delayed_qc | 5609 | 0.11 | 57 | n=20 | site_code n=334 |
| vessel_fishsoop_realtime_qc | 62174 | 0.67 | 15 | n=51 |  |
| vessel_sst_delayed_qc | 2192 | 0.10 | 38 | n=34 | platform_code n=3 |
| vessel_sst_realtime_nonqc | 48678 | 0.93 | 53 | n=20 | platform_code n=26 |
| vessel_trv_realtime_qc | 4576 | 3.24 | 15 | n=164 | platform_code n=2 |
| vessel_xbt_delayed_qc | 127345 | 7.46 | 61 | n=46 | SOOP_line_label n=23 |
| vessel_xbt_realtime_nonqc | 5517 | 0.09 | 11 | n=58 | XBT_line n=7 |

## wave

| dataset | files | GB | cols | years | other partitions |
|---|---|---|---|---|---|
| wave_buoy_delayed_qc | 11265 | 0.43 | 35 | n=625 | site_name n=179 |
| wave_buoy_realtime_nonqc | 2626 | 0.09 | 18 | n=35 | site_name n=146 |
