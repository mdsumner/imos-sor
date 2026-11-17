# aodn-cloud-optimised: Zarr stores

100 stores, harvested 2026-11-17 by scripts/zarr_inventory.py (metadata + 1-D coords only). `s3://aodn-cloud-optimised/<store>`, anonymous, ap-southeast-2. All Zarr v2, consolidated, Blosc-lz4. Extent is pixel centres.


## model

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| model_sea_level_anomaly_gridded_delayed | 12022x351x641 | 5x351x641 | 57.00..185.00 | -60.00..10.00 | 0.2 | 1993-01-01..2025-11-30 | 663be14d-bb88-4e84-a34c-6c84a0196e2e |
| model_sea_level_anomaly_gridded_realtime | 2528x351x641 | 5x351x641 | 57.00..185.00 | -60.00..10.00 | 0.2 | 2020-01-01..2026-11-14 | 0c9eb39c-9cbe-4c6a-8a10-5867087e703a |

## mooring

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| mooring_wave_timeseries_delayed_qc | 127761x64x90 | 1284x62x89 | ['TIME', 'FREQUENCY', 'DIR'] |  |  | 2011-01-01..2026-04-20 | aaebf991-b79d-4670-a1c5-a0de9bf649ce |

## radar

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| radar_BonneyCoast_velocity_hourly_averaged_delayed_qc | 46829x69x69 | 100x69x69 | ['TIME', 'I', 'J'] |  |  | 2010-07-16..2017-03-27 | 38dd003d-2f71-4715-bd3f-4b1cfdce391d |
| radar_BonneyCoast_velocity_hourly_averaged_realtime_nonqc | 39729x69x69 | 100x69x69 | ['TIME', 'I', 'J'] |  |  | 2010-07-16..2017-03-27 | 4a1608ab-ebdd-4f98-93c3-15f2da87bfa0 |
| radar_CapricornBunkerGroup_velocity_hourly_averaged_delayed_qc | 63097x64x72 | 100x64x72 | 150.78..153.55 | -24.20..-21.92 | 0.03904 | 2007-10-15..2017-04-17 | 8a2d2824-0557-4110-a561-01ec35a9583d |
| radar_CapricornBunkerGroup_velocity_hourly_averaged_realtime_nonqc | 36562x64x72 | 100x64x72 | 150.78..153.55 | -24.20..-21.92 | 0.03904 | 2012-01-01..2017-04-17 | 422db51d-596c-4d1c-86a0-b89413c5187e |
| radar_CapricornBunkerGroup_wave_delayed_qc | 31196x64x72 | 100x64x72 | 150.78..153.55 | -24.20..-21.92 | 0.03904 | 2009-08-01..2017-04-07 | 400a1237-af4d-45c6-a292-788cf0212522 |
| radar_CapricornBunkerGroup_wind_delayed_qc | 49347x64x72 | 100x64x72 | 150.78..153.55 | -24.20..-21.92 | 0.03904 | 2009-08-01..2017-04-17 | 742dc902-b300-4e3e-839f-04d03671aa09 |
| radar_CoffsHarbour_velocity_hourly_averaged_delayed_qc | 71631x167x114 | 100x167x114 | 153.01..154.78 | -31.61..-29.36 | 0.01562 | 2012-03-07..2026-06-30 | 85da1645-2c63-45fa-97b5-4125165b999d |
| radar_CoffsHarbour_velocity_hourly_averaged_realtime_nonqc | 13703x167x114 | 100x167x114 | 153.01..154.79 | -31.61..-29.36 | 0.01571 | 2025-03-27..2026-11-17 | 82bc6673-c9cb-4afc-8b5d-0e65b097bfdc |
| radar_CoffsHarbour_wave_delayed_qc | 49066x167x114 | 100x167x114 | 153.01..154.78 | -31.61..-29.36 | 0.01562 | 2012-03-27..2020-12-11 | e32e51d9-b0a5-4b95-9906-44e0c6c8d516 |
| radar_CoffsHarbour_wind_delayed_qc | 2130x167x114 | 30x167x114 | 153.01..154.78 | -31.61..-29.36 | 0.01562 | 2012-04-01..2012-06-29 | ffe8f19c-de4a-4362-89be-7605b2dd6b8c |
| radar_CoralCoast_velocity_hourly_averaged_delayed_qc | 45680x73x65 | 100x73x65 | ['TIME', 'I', 'J'] |  |  | 2019-04-18..2026-06-30 | f7b36a1c-0936-4da6-b47f-94ed538b367e |
| radar_CoralCoast_velocity_hourly_averaged_realtime_nonqc | 9502x73x65 | 100x73x65 | ['TIME', 'I', 'J'] |  |  | 2025-01-07..2026-11-16 | 0dd3832a-cf67-4068-a446-a9c91c77273e |
| radar_Newcastle_velocity_hourly_averaged_delayed_qc | 52120x69x69 | 100x69x69 | ['TIME', 'I', 'J'] |  |  | 2017-11-30..2026-06-30 | 6dca1f8a-8337-4551-ac4b-a2d35ec6f333 |
| radar_Newcastle_velocity_hourly_averaged_realtime_nonqc | 9519x69x69 | 100x69x69 | ['TIME', 'I', 'J'] |  |  | 2025-06-11..2026-11-17 | e952bcee-79e7-4995-91ad-a7e6408d29ce |
| radar_NorthWestShelf_velocity_hourly_averaged_delayed_qc | 25892x51x55 | 100x51x55 | 111.13..115.03 | -22.58..-19.21 | 0.07225 | 2021-04-01..2026-06-30 | 23c27e4f-c982-44e9-9ab7-71094d297549 |
| radar_NorthWestShelf_velocity_hourly_averaged_realtime_nonqc | 10176x51x55 | 100x51x55 | 111.13..115.03 | -22.58..-19.21 | 0.07225 | 2025-01-01..2026-11-17 | ba9110f1-072c-4d15-8328-2091be983991 |
| radar_RottnestShelf_velocity_hourly_averaged_delayed_qc | 87880x92x62 | 100x92x62 | 113.15..115.74 | -33.43..-30.15 | 0.04244 | 2010-02-23..2026-06-30 | 028b9801-279f-427c-964b-0ffcdf310b59 |
| radar_RottnestShelf_velocity_hourly_averaged_realtime_nonqc | 8923x92x62 | 100x92x62 | 113.15..115.73 | -33.43..-30.15 | 0.04224 | 2025-07-23..2026-11-17 | 8b469535-eb48-4f1f-9612-bdf2e83cdce8 |
| radar_RottnestShelf_wave_delayed_qc | 41925x92x62 | 100x92x62 | 113.15..115.73 | -33.43..-30.15 | 0.04224 | 2010-04-01..2019-06-07 | 9c6d6a0c-4983-4cb5-b119-02c11ce6af4e |
| radar_RottnestShelf_wind_delayed_qc | 65735x92x62 | 100x92x62 | 113.15..115.73 | -33.43..-30.15 | 0.04224 | 2010-04-01..2019-06-07 | 5ad9a6da-3f0b-4b2f-8212-48b386e1b98c |
| radar_SouthAustraliaGulfs_velocity_hourly_averaged_delayed_qc | 80674x74x102 | 100x74x102 | 132.95..137.46 | -37.46..-34.82 | 0.04465 | 2009-11-23..2026-03-23 | cb2e22b5-ebb9-460b-8cff-b446fe14ea2f |
| radar_SouthAustraliaGulfs_velocity_hourly_averaged_realtime_nonqc | 77034x74x102 | 100x74x102 | 132.95..137.46 | -37.46..-34.82 | 0.04465 | 2009-11-23..2026-03-23 | d83ef640-827e-4990-8c35-7c1a1aa587a9 |
| radar_SouthAustraliaGulfs_wave_delayed_qc | 24732x74x102 | 100x74x102 | 132.95..137.44 | -37.45..-34.82 | 0.04445 | 2011-04-01..2020-12-03 | 19da2ce7-138f-4427-89de-a50c724f5f54 |
| radar_SouthAustraliaGulfs_wind_delayed_qc | 38129x74x102 | 100x74x102 | 132.95..137.44 | -37.45..-34.82 | 0.04445 | 2011-04-01..2020-12-05 | db049981-3d4e-4cb2-9c4b-e697650845b9 |
| radar_TurquoiseCoast_velocity_hourly_averaged_delayed_qc | 101533x60x59 | 100x59x59 | ['TIME', 'I', 'J'] |  |  | 2009-03-27..2026-06-30 | 055342fc-f970-4be7-a764-8903220d42fb |
| radar_TurquoiseCoast_velocity_hourly_averaged_realtime_nonqc | 12659x60x59 | 100x60x59 | ['TIME', 'I', 'J'] |  |  | 2025-01-07..2026-11-17 | 52f09a23-63a2-4c14-8b3b-1fc7c8167281 |

## satellite

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| satellite_austemp_degree-heating-day_australia | 151x1890x2685 | 1x500x500 | 110.01..163.69 | -45.99..-8.21 | 0.02 | 2025-12-01..2026-04-30 | e1f2476a-b801-4a1f-9fbe-727b4f76f726 |
| satellite_austemp_dhd_14day | 2237x1890x2685 | 10x315x537 | 110.01..163.69 | -45.99..-8.21 | 0.02 | 2012-01-01..2026-04-30 | e1f2476a-b801-4a1f-9fbe-727b4f76f726 |
| satellite_austemp_heatwave_14day | 5428x2000x3900 | 5x1000x1300 | 96.00..174.00 | -48.00..-8.00 | 0.02 | 2012-01-01..2026-11-10 | 2ffccdad-1197-4e41-b412-a9033517cfb2 |
| satellite_austemp_sst-anomaly_australia | 1096x1890x2685 | 1x500x500 | 110.01..163.69 | -45.99..-8.21 | 0.02 | 2023-11-17..2026-11-10 | 62f6b449-90dc-45bf-8acb-ae52e8a58c5c |
| satellite_austemp_sst_14day | 5427x1890x2685 | 7x630x895 | 110.01..163.69 | -45.99..-8.21 | 0.02 | 2012-01-01..2026-11-10 | 62f6b449-90dc-45bf-8acb-ae52e8a58c5c |
| satellite_chlorophylla_carder_1day_aqua | 7289x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2022-08-13 | 43ac4663-c8de-4eb0-9711-3da65cbecdd3 |
| satellite_chlorophylla_gsm_1day_aqua | 8040x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-11-29 | f73daf07-eb81-4995-a72a-ca903834509f |
| satellite_chlorophylla_gsm_1day_noaa20 | 1363x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2023-02-08..2026-11-05 | ad4d6908-3a36-4991-996a-5b00ac162794 |
| satellite_chlorophylla_gsm_1day_snpp | 5295x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | 6447f562-9063-4879-8598-ca0b5c4e0175 |
| satellite_chlorophylla_oc3_1day_aqua | 8020x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-11-15 | d7a14921-8f3f-4522-9a54-e7d1df969c8a |
| satellite_chlorophylla_oc3_1day_noaa20 | 1359x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2023-02-08..2026-11-05 | 77f46a04-f07d-4968-a5f9-1da8df9706a7 |
| satellite_chlorophylla_oc3_1day_snpp | 5293x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | d222bd3f-b1a8-46f1-b462-90e44c5d9b44 |
| satellite_chlorophylla_oci_1day_aqua | 8033x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | 24055e3a-94e5-40bb-b97f-7519f0482d6a |
| satellite_chlorophylla_oci_1day_noaa20 | 1064x9601x13601 | 1x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2023-02-08..2026-11-07 | a9e03db8-f277-45d1-821d-cfcbfe8ae6be |
| satellite_chlorophylla_oci_1day_snpp | 5296x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | d7f9eb3f-b81e-4421-8c75-761ffb33db5d |
| satellite_diffuse_attenuation_coefficent_1day_aqua | 8062x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | a8632154-b8e5-493d-acd4-e458fae3ae26 |
| satellite_diffuse_attenuation_coefficent_1day_noaa20 | 1367x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2023-02-08..2026-11-07 | 37751f5b-3c93-40df-9913-951df310cbc8 |
| satellite_diffuse_attenuation_coefficent_1day_snpp | 5297x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | 697aa9e7-bf24-4f9e-9950-d5cfd78f1b35 |
| satellite_ghrsst_l3c_1day_daytime_noaa19_australia | 5862x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2009-02-23..2025-06-08 | e6782131-821c-4237-b2a9-27c6aaa8608c |
| satellite_ghrsst_l3c_1day_daytime_noaa19_southern_ocean | 1260x2500x10000 | 5x500x500 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 2009-02-23..2012-09-04 | be9103bd-dbbb-42a8-949d-92e8543a4d92 |
| satellite_ghrsst_l3c_1day_daytime_snpp_australia | 5128x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-03-01..2026-11-02 | bcf6a870-2591-492e-b340-931f38de5975 |
| satellite_ghrsst_l3c_1day_nighttime_himawari8 | 2656x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2015-09-01..2022-12-12 | 72b65fb8-84e1-4a56-b32c-7f15970903d2 |
| satellite_ghrsst_l3c_1day_nighttime_noaa19_australia | 5632x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2009-02-22..2025-06-08 | 46ebc1a9-c503-4435-b85c-11fe16176c8d |
| satellite_ghrsst_l3c_1day_nighttime_noaa19_southern_ocean | 5719x2500x10000 | 5x500x500 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 2009-02-22..2025-06-08 | 91495e9a-6590-4fb9-bb63-0901a8a4b7b1 |
| satellite_ghrsst_l3c_1day_nighttime_snpp_australia | 5164x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-03-01..2026-11-02 | a05817da-fdab-483a-a965-b26fe364ad7c |
| satellite_ghrsst_l3c_4hour_himawari8 | 15770x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2015-09-01..2022-12-13 | 06d2fff4-8e2c-4bd7-b98f-cd98e588df6f |
| satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_australia | 5253x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-08-31 | d7f3178d-869a-4eac-959d-71d1f5e24888 |
| satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_southernocean | 2671x2500x10000 | 5x500x500 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 2018-11-16..2026-11-09 | 4a136fc6-3ac7-4af1-870f-f5827d6dfcb4 |
| satellite_ghrsst_l3s_1day_daynighttime_single_sensor_australia | 11870x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-21..2024-11-08 | a136eee7-a990-4c06-a4f6-915657a2464e |
| satellite_ghrsst_l3s_1day_daynighttime_single_sensor_southernocean | 8153x2500x10000 | 5x250x250 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 1992-03-21..2025-03-01 | 165a23d7-5ef3-4cab-9e02-90c8adb941dd |
| satellite_ghrsst_l3s_1day_daytime_multi_sensor_australia | 5328x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-11-10 | 52ad55a5-b537-4e10-8a81-22d9317c81f2 |
| satellite_ghrsst_l3s_1day_daytime_single_sensor_australia | 11782x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-21..2025-06-06 | 8bd3fe33-fd98-4307-ad23-424ad9a2907b |
| satellite_ghrsst_l3s_1day_nighttime_geopolar_multi_sensor_australia | 2639x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2015-09-01..2022-12-12 | 7d8d046b-6002-4897-b781-04e7324d6af8 |
| satellite_ghrsst_l3s_1day_nighttime_multi_sensor_australia | 5352x4500x6000 | 2x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-11-10 | d3e3bce3-adb4-433a-a192-93abc91899d3 |
| satellite_ghrsst_l3s_1day_nighttime_single_sensor_australia | 12063x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-21..2025-06-06 | aaad092c-c3af-42e6-87e0-bdaef945f522 |
| satellite_ghrsst_l3s_1month_daynighttime_multi_sensor_australia | 176x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-16..2026-10-16 | 73e6608c-cbf5-4a01-9c95-1f137de6cbac |
| satellite_ghrsst_l3s_1month_daynighttime_multi_sensor_southernocean | 80x2500x10000 | 3x900x1000 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 2018-12-16..2026-09-15 | 579fc1ac-6ee5-40e2-9170-6a857e9b40da |
| satellite_ghrsst_l3s_1month_daynighttime_single_sensor_australia | 365x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-16..2022-12-16 | d6f49c4a-8b75-4d05-acd4-b9c085bf4de0 |
| satellite_ghrsst_l3s_1month_daynighttime_single_sensor_southernocean | 353x2500x10000 | 5x500x500 | 2.51..202.49 | -77.49..-27.51 | 0.02 | 1992-03-16..2022-12-16 | a05d8ceb-ab0c-4bad-8126-d16d535e73c1 |
| satellite_ghrsst_l3s_1month_daytime_multi_sensor_australia | 176x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-16..2026-10-16 | e3b2531b-a662-43de-9a8b-8e2b385267b3 |
| satellite_ghrsst_l3s_1month_daytime_single_sensor_australia | 370x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-16..2022-12-16 | b8e9f613-9611-4692-a958-07f100d2c763 |
| satellite_ghrsst_l3s_1month_nighttime_multi_sensor_australia | 177x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-16..2026-10-16 | 1aa787da-a9ba-494a-ae22-0c3eee2491e1 |
| satellite_ghrsst_l3s_1month_nighttime_single_sensor_australia | 370x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-16..2022-12-16 | d9618fb2-1a71-4afd-b1c8-56a6871b224a |
| satellite_ghrsst_l3s_3day_daynighttime_multi_sensor_australia | 4919x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2013-01-01..2026-11-01 | 4cbb9eeb-9ed3-4079-a180-2293a2c219b9 |
| satellite_ghrsst_l3s_3day_daytime_multi_sensor_australia | 5324x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-11-09 | 08e04227-4da1-479b-bec1-06ee27a69a40 |
| satellite_ghrsst_l3s_3day_nighttime_multi_sensor_australia | 5317x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-11-09 | b28ab00c-06f9-4cef-9053-4ff3bf537bb7 |
| satellite_ghrsst_l3s_6day_daynighttime_multi_sensor_australia | 30x4500x6000 | 1x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2026-09-30..2026-11-07 | 95b81267-bad2-4939-8559-45b0d0c6f2e9 |
| satellite_ghrsst_l3s_6day_daynighttime_single_sensor_australia | 11994x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-18..2025-02-17 | 023ae12a-8c0c-4abc-997a-7884f9fec9cd |
| satellite_ghrsst_l3s_6day_daytime_multi_sensor_australia | 5327x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2026-11-07 | f07c3d3f-547b-4818-9d2f-12e872c7e158 |
| satellite_ghrsst_l3s_6day_daytime_single_sensor_australia | 12114x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-18..2025-06-03 | a5cad244-c33e-4083-b8a9-09ef59500b3d |
| satellite_ghrsst_l3s_6day_nighttime_multi_sensor_australia | 3000x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 2012-01-01..2020-03-18 | e1908591-b3cf-42aa-a32f-424322b28165 |
| satellite_ghrsst_l3s_6day_nighttime_single_sensor_australia | 11979x4500x6000 | 5x500x500 | 70.01..189.99 | -69.99..19.99 | 0.02 | 1992-03-19..2025-06-04 | f9d6616a-f359-4418-979a-e7b89b5b9086 |
| satellite_ghrsst_l4_gamssa_1day_multi_sensor_world | 6524x720x1440 | 3x360x720 | -179.88..179.88 | -89.88..89.88 | 0.25 | 2008-07-23..2026-11-15 | 2d496463-600c-465a-84a1-8a4ab76bd505 |
| satellite_ghrsst_l4_ramssa_1day_multi_sensor_australia | 7446x1081x1561 | 3x360x720 | 60.00..190.00 | -70.00..20.00 | 0.08333 | 2006-06-12..2026-11-15 | a4170ca8-0942-4d13-bdb8-ad4718ce14bb |
| satellite_nanoplankton_fraction_oc3_1day_aqua | 8041x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | 9fde091c-9d38-4b2f-ba23-c262c21a41a2 |
| satellite_net_primary_productivity_gsm_1day_aqua | 8041x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | 27cc65c0-d453-4ba3-a0d6-55e4449fee8c |
| satellite_net_primary_productivity_oc3_1day_aqua | 8041x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | b35b829c-9149-46c6-9e25-d0fd03463280 |
| satellite_optical_water_type_1day_aqua | 7289x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2022-08-13 | 60e57a2e-f88c-4b18-a3a1-1164c6259a10 |
| satellite_optical_water_type_1day_noaa20 | 379x9601x13601 | 5x600x800 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2025-10-18..2026-11-07 | 5f359ca7-396a-4c1a-8388-77a50ad39859 |
| satellite_optical_water_type_1day_snpp | 364x9601x13601 | 5x500x500 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | 8f44f09a-07a3-4f9b-ba26-2fc4983fef69 |
| satellite_picoplankton_fraction_oc3_1day_aqua | 8040x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-06 | bc428d0b-eff7-41b9-8d4c-10e666ee1312 |
| satellite_sst_1day_aqua | 8052x7001x10001 | 5x500x500 | 80.00..180.00 | -60.00..10.00 | 0.01 | 2002-07-04..2024-12-25 | 468f550b-bbd8-42b1-91b5-313d5898d9e6 |
| satellite_sst_1day_snpp | 5292x9601x13601 | 5x500x500 | 78.00..180.00 | -60.00..12.00 | 0.0075 | 2012-01-03..2026-11-02 | 8e00907f-716d-4080-b212-534fcd78a602 |
| satellite_wind_altimeter_delayed_qc | 2868x5000x8500 | 40x2000x2000 | 95.00..179.99 | -48.99..1.00 | 0.009995 | 2017-10-24..2025-08-31 | b02b929f-2caf-45d4-ac60-d4632b7ca0ca |

## station

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| station_lucinda_jetty_daily_satlantic_hyperocr | 137x84678 | 137x265 | ['WAVELENGTH_Ed', 'TIME'] |  |  | 2015-06-25..2018-06-11 | 4ac6bf81-cd37-4611-8da8-4d5ae5e2bda3 |
| station_lucinda_jetty_daily_satlantic_hyperocr_derived_product | 461x108031 | 461x2078 | ['WAVELENGTH', 'TIME'] |  |  | 2019-09-18..2026-04-21 | 4ac6bf81-cd37-4611-8da8-4d5ae5e2bda3 |
| station_lucinda_jetty_dalec | 200x3633664 | 200x1000 | ['WAVELENGTH_Ed', 'TIME'] |  |  | 2016-05-26..2018-12-13 | 4ac6bf81-cd37-4611-8da8-4d5ae5e2bda3 |
| station_lucinda_jetty_dalec_derived_product | 596x2920197 | 596x1000 | ['WAVELENGTH', 'TIME'] |  |  | 2016-05-26..2018-12-13 | 4ac6bf81-cd37-4611-8da8-4d5ae5e2bda3 |
| station_lucinda_jetty_hourly_satlantic_hyperocr | 137x20532955 | 137x5000 | ['WAVELENGTH_Ed', 'TIME'] |  |  | 2018-01-30..2018-10-23 | 4ac6bf81-cd37-4611-8da8-4d5ae5e2bda3 |

## vessel

| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |
|---|---|---|---|---|---|---|---|
| vessel_satellite_radiance_delayed_qc | 200x2781247 | 200x1000 | -178.95..178.78 | -46.92..-8.33 | 3.1e-05 | 2011-07-29..2026-05-11 | 28f8bfed-ca6a-472a-84e4-42563ce4df3f |
| vessel_satellite_radiance_derived_product | 596x469721 | 596x10000 | 77.02..152.01 | -23.81..-8.49 | 4.6e-05 | 2013-07-30..2025-05-17 | 28f8bfed-ca6a-472a-84e4-42563ce4df3f |
