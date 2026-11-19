# Animal tracking in IMOS (AATAMS, the Animal Tracking Facility)

Surveyed on 2026-11-19 with `R/13_animal_tracking.R`, which runs DuckDB on AODN's cloud-optimised Parquet (anonymous
S3). File counts come from listings of `s3://imos-data/IMOS/AATAMS/`. NCI's mirror (`/g/data/sh74/IMOS_AODN/IMOS/AATAMS/`)
has the same tree and counts, but not the Parquet. Tables: `inventory/animal_{sattag_campaigns,ctd_by_species_site,
acoustic_species,acoustic_installations}.csv`.

IMOS tracking comes in three streams. Satellite-relay tags carry CTDs and are mostly on seals. Acoustic telemetry
tracks fish, sharks, rays, turtles and crocodiles on coastal receivers. There are a few small archival sets.

## Where it is

| `IMOS/AATAMS/...` | files | GB | what |
|---|---|---|---|
| `satellite_tagging/MEOP_QC_CTD` | 564 | 7.95 | MEOP-QC'd CTD profiles, one `*_prof.nc` (Argo format) per tag, 41 campaigns |
| `satellite_tagging/ATF_Location_QC_DM` | 365 | 2.02 | 52 campaigns × 7 CSV tables (`ctd diag dive haulout metadata ssmoutputs summary`, `gps` for turtles) |
| `satellite_tagging/ATF_Location_QC_NRT` | 22 | 0.11 | the same for the 3 current campaigns (ct189, ct190, tu126) |
| `satellite_tagging/SMRU_CTD_High_Resolution_Data` | 46 | 1.34 | full-resolution dive records (`*_tdr.zip`) from recovered tags, 2018 |
| `satellite_tagging/emperor_penguins` | 3 | <0.01 | Argos campaigns 1986, 1998, 2012–13 |
| `AATAMS_sattag_nrt` | 125,803 | 5.02 | one NetCDF per near-real-time profile, 320 tags (WMO `Q99…`); last written 2016–2019 |
| `acoustic_detections_QC` | 7,053 | 40.74 | QC'd detections, one CSV per tag |
| `acoustic_detections_QC_summary` | 164 | 4.69 | hourly detections, one CSV per species |
| `acoustic_tagging` | 3,779 | 5.81 | the static 2007–2017 release (doi:10.4225/69/5979810a7dd6f), superseded by the two above |
| `archival_tagging` | 30 | <0.01 | short-tailed shearwaters (one file, 2010–2012), snow petrels (29 geolocator tags) |

AODN publishes 22 Parquet datasets, `animal_*` in `s3://aodn-cloud-optimised` (`inventory/parquet_inventory.csv`):
- the CTD profiles (`animal_ctd_satellite_relay_tagging_delayed_qc`, 1.3 GB)
- the acoustic detections, full (1.65 GB) and hourly (0.30 GB)
- the 7 location-QC tables plus metadata, each in delayed and real-time versions

## Satellite-relay tags (SMRU SRDL, Argos; GPS on turtles)

- **689 tags in 55 campaigns, 2007–2026** (location-QC metadata). By species:
  - southern elephant seal 500 tags, 35 campaigns: Iles Kerguelen, Davis, Macquarie Island
  - olive ridley turtle 70 (2022–2026)
  - Weddell seal 61 (2017–2024): Dumont d'Urville, Scott Base, Davis, Halley
  - Australian sea lion 34 (2009–2016, SA islands)
  - flatback turtle 15 and green turtle 9 (2022)
- **Location QC:** each campaign's raw Argos fixes come with state-space-model tracks and their errors (`ssm_*` columns;
  the `ssmoutputs` table is the fitted track). Rows in delayed mode:
  - 1.68 million Argos locations (`diag`)
  - 9.0 million dive records
  - 4.65 million CTD rows
  - 0.44 million fitted positions
  - 12,443 GPS fixes (turtles)
  - 40,449 haul-outs
- **CTD profiles** (MEOP-QC'd, delayed mode): 262,849 profiles from 551 tags, 2004-01 → 2024-02. 77% are south of
  50°S and 42% south of 60°S.

  | species, site | tags | profiles | years | median depth (dbar) |
  |---|---|---|---|---|
  | elephant seal, Kerguelen | 248 | 133,469 | 2008–2022 | 530 → 1000 from 2018 |
  | elephant seal, Davis | 55 | 31,083 | 2011–2017 | 502 |
  | elephant seal, Macquarie | 30 | 16,066 | 2004–2010 | 552 |
  | elephant seal, Casey | 25 | 13,115 | 2012 | 596 |
  | elephant seal, Campbell | 18 | 5,197 | 2012–2015 | 492 |
  | Weddell seal, Davis | 27 | 17,350 | 2006–2011 | 158 |
  | Weddell seal, Ross Sea | 35 | 15,119 | 2019–2020 | 1000 (positions bad, `notes/issues.md` 23) |
  | Weddell seal, Dumont d'Urville | 28 | 5,159 | 2007–2015 | 114 |
  | Weddell seal, Scott Base | 12 | 2,771 | 2014–2017 | 296 |
  | fur seal, Montague Island (NSW) | 32 | 11,253 | 2012–2014 | 1000 (positions bad, issue 23) |
  | flatback and olive ridley turtles, northern Australia | 39 | 12,023 | 2022–2024 | 1000 |

  - **Salinity** is on 97% of the elephant seal profiles to 2017 and 78% after. The turtle profiles mostly have
    none (13% and 43%).
  - **Other sensors** are rare: oxygen on 138 profiles, fluorescence on 3,294 and light on 3,239, all on elephant
    seals in 2018–2022, plus fluorescence on 39 Weddell seal profiles.
  - **The Parquet ends in 2024-02.** The location-QC `ctd` tables and the MEOP files go on to 2025–2026.
- **Labels are inconsistent** (issue 23): "Southern ellie" (2004–2017) and "Southern elephant seal" (2018–) are the
  same species. "Weddel seal" (one tag) is a typo. Some `location` values are campaign codes (`ct91`, `ct101`,
  `ct110`) rather than places.

## Acoustic telemetry (IMOS Australian Animal Acoustic Telemetry Database)

- **164 species, 6,923 tagged animals, 81 million detections**, at 2,740 receiver stations in 220 installations,
  2007–2026 (the hourly Parquet; detections are the sum of its hourly counts).
- **Coastal Australia only:** 10.7–46.8°S, 113.6–168.2°E. By rough region (lat/lon boxes, so approximate):
  - Queensland 1,022 stations (53% of detections)
  - NSW 789 (24%)
  - northern WA 262
  - SA 224
  - Victoria 179
  - Tasmania 130
  - NT 44
  - southern WA 90

  There is nothing in the Southern Ocean.
- **Most animals:** tiger shark 353, bull shark 342, grey reef shark 288, Port Jackson shark 255, common coral trout
  250, saltwater crocodile 246, blacktip reef shark 217, snapper 185, speartooth shark 175, sea mullet 166. 42
  species have 50 or more animals.
- **Most detections:** grey reef shark 8.6 million, saltwater crocodile 5.9 million (Wenlock River, the busiest
  installation at 7.6 million), blacktip reef shark 5.0 million, Port Jackson shark 4.9 million.
- **By year:** the number of animals detected peaks in 2012–2013 (1,565 and 1,869, with 9.9 and 13.5 million
  detections) and is 476–820 a year in 2017–2025.
- **Fuller records:** the per-tag CSVs (40.7 GB) and the full detection Parquet keep each detection, with QC flags
  (`Detection_QC`, `Velocity_QC`, `Distance_QC`, …) and receiver and transmitter metadata. Some tags carry
  temperature or depth sensors (`transmitter_sensor_*`).

## For this project

- **The seal CTD record is the in-situ link to the Southern Ocean side of the frame.** It has over 200,000 profiles
  south of 50°S, from Kerguelen, Davis, Casey, Macquarie and the Ross Sea, much of it under or near winter sea ice,
  where satellite SST is weakest. Their near-surface temperatures could check the L3S and MUR in the ice zone, and
  `notes/issues.md` 20–22 is where that matters.
- **The CTD profiles map onto the same S2 L5 cells** as everything else (point → cell, exact sums of T/S by depth
  bin). The Parquet is enough to do that from here; the MEOP NetCDF on sh74 or S3 has the full metadata.
- **The acoustic network is a coastal and estuarine record.** It fits the EEZ, marine-park and bioregion side of the
  project (receiver stations against `amp` and IMCRA), not SST trends.
- **NCI:** for the survey, the Parquet from here is enough (DuckDB, seconds to minutes). Gadi pays off for passes
  over the raw files (the 40.7 GB of per-tag CSVs, 125,803 NRT NetCDFs, the TDR zips). It also helps where tracks are
  joined to fields already on Gadi: the L3S on sh74, ERA5, the ocean reanalyses.
