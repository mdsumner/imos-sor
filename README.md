# imos-sor

A survey of IMOS data stores, starting from the IMOS *State and Trends of
Australia's Ocean Report* (STAR, <https://www.imosoceanreport.org.au/>).
Two aims:

1. **trends and status** in the manner of the trend.* family (exact, mergeable
   statistics; see <https://australianantarcticdivision.github.io/trend/>), and
2. **a pivot to higher-resolution Australian regional data** (marine here,
   terrestrial later), regionalised by the EEZ, Australian Marine Parks and
   bioregions. Where products also span the globe or the Southern Ocean
   (GHRSST first of all), use that overlap to connect to global, Antarctic
   and sub-Antarctic records.

Status (2026-11-17): survey done; region sets and coverage tables built; first
5-day block compared with trend.sst (steps 1–3 of section 7). No statistics pipeline yet. Everything below can be
re-run with the scripts in `scripts/` (Python harvesters, `python3 -I`) and
`R/` (boundaries and coverage, `Rscript R/0N_*.R` from the repo root, about 2 minutes).
Large or regenerable outputs go to `data/` (gitignored); checks are committed in
`boundaries/`.

Decisions so far:
- EEZ = GA AMB2020 **as amended by the Perth Treaty 1997** (GA's recommendation).
- The STAR regions (six + fill-ins) and IMCRA provincial are kept as **separate region sets**.
- The long-term frame is **Australia + AAT**: every territory including HIMI and
  the AAT, to match the reach of GA DEA plus Antarctica.
- Tools: the hypertidy suite (gdalraster with mdim, zaro, tabularberg,
  controlledburn) plus the usual spatial R set.

| path | what |
|---|---|
| `notes/report.md` | STAR 2020 inventory: 27 time series, sources, regions, headline numbers, and how each one could be refreshed now |
| `notes/zarr_stores.md` | all 100 Zarr stores in `s3://aodn-cloud-optimised`: grid, extent, step, time span, chunks, catalogue UUID |
| `notes/parquet_datasets.md` | all 70 Parquet datasets there (158 GB): files, size, partitions |
| `notes/boundaries.md` | EEZ, marine parks, bioregions and terrestrial sources (endpoints checked) |
| `notes/regions.md` | the five region sets, the shared 0.02° lattice, coverage tables and their checks |
| `notes/product_coverage.md` | every gridded store × EEZ territory and AMP network: % inside the product domain (Heard, AAT gaps) |
| `notes/issues.md` | data issues found (a partial Zarr append, Zarr lagging the NetCDF, ...) |
| `R/01_boundaries.R` … `R/04_product_coverage.R` | region sets → lattice → coverage tables → product coverage |
| `R/05_time_axes.R` … `R/08_compare.R` | time-axis audit → S2 L5 mapping → 5-day block sums (S2 + regions) → comparison with trend.sst |
| `nci/` | IMOS on NCI: the sh74 IMOS/AODN mirror and BoM's qm43 SST archive (fv01 = IMOS operational, fv02 = BoM reprocessing), projects to join, the Gadi probe and inventory job, and raad.virtualize candidates (`nci/README.md`) |
| `notes/block_2024-01-04.md` | first 5-day block: IMOS L3S vs OISST/MUR on S2 L5; exact EEZ means vs L5 cell selections |
| `boundaries/` | committed checks: `regions.csv`, `lattice.csv`, `coverage_check.csv`, `product_coverage.csv`, `SOURCES.txt` |
| `inventory/*.jsonl, *.csv` | raw harvests: `zarr_inventory`, `parquet_inventory`, `cloud_optimised_provenance` (config → source NetCDF prefix + catalogue UUID), `imos-data_tree_L3.txt` |
| `scripts/` | `zarr_inventory.py`, `parquet_inventory.py`, `config_provenance.py`, `summarise_inventory.py` (run with `python3 -I`) |

## 1. The report in brief

- **One edition only**: the 2019 report, published March 2020
  (Richardson, Eriksen, Moltmann, Hodgson-Johnston, Wallis (Eds); 70+
  authors; DOI per section, 10.26198/5e16…). It was billed as a "living"
  report to be updated every two years. No update has appeared on the site,
  and searches turned up no later edition.
- 27 time series in four themes: physical/chemical (6), productivity (7),
  water quality (6), animals (8). Pelagic only.
- **Regions**: the six Commonwealth marine bioregional plan regions (South-west, North-west,
  North, Coral Sea, Temperate East, South-east; the GBR is outside them),
  a "continental EEZ", two SST/KE boxes (east 24–37.5°S 150–160°E; west
  21–36°S 108–116°E), and the seven National Reference Stations.
  **No marine parks**: 2.4 only says its phenology regions "could help"
  with drawing park boundaries.
- Trend units vary between sections (per century, per decade, per year,
  % over the period, % per decade). There is no shared methods section,
  and no code or derived data were released, only figures and PDFs.
- Its satellite chlorophyll, NPP and clarity work used NASA MODIS and Oregon
  State VGPM products. Its SST work used HadISST, AVHRR L3S and SSTAARS.
  IMOS now publishes its own gridded equivalents of all of these (below).

Full per-section inventory and refresh map: `notes/report.md`.

## 2. The stores

| store | access | what |
|---|---|---|
| `s3://imos-data` | anonymous S3, ap-southeast-2 | NetCDF/CSV archive. 27 contributor prefixes (IMOS, AIMS, BoM, CSIRO, TERN, UNSW, UWA, states…). `IMOS/` holds 19 facilities (SRS, ANMN, DWM, SOOP, Argo, AATAMS, ACORN, ANFOG, …) |
| `s3://aodn-cloud-optimised` | anonymous S3, ap-southeast-2 | 100 Zarr v2 stores (gridded) + 70 Parquet datasets (tabular, hive-partitioned by `polygon=` and `timestamp=`). Built by [aodn/aodn_cloud_optimised](https://github.com/aodn/aodn_cloud_optimised): 180 JSON configs that link each store to its source prefix in `imos-data` and its GeoNetwork UUID (`inventory/cloud_optimised_provenance.csv`) |
| `s3://imos-data/IMOS/BGC_DB/harvested_from_CSIRO/` | anonymous S3 | NRS and CPR biology as plain CSVs (phyto/zoo raw counts, chemistry, pigments, picoplankton, TSS, larval fish), refreshed 2026-11-10. These are the inputs to [planktonr](https://github.com/PlanktonTeam/planktonr) and to the biology half of the report. They are **not** in the cloud-optimised bucket |
| thredds.aodn.org.au | OPeNDAP / HTTP | the same archive via THREDDS |
| geoserver-123.aodn.org.au, geoserver-portal.aodn.org.au | WFS (csv) | portal layers (planktonr uses both) |
| catalogue-imos.aodn.org.au | GeoNetwork | metadata by UUID |

GDAL reads the Zarr stores directly:

```sh
export AWS_NO_SIGN_REQUEST=YES AWS_REGION=ap-southeast-2   # the default region in this environment is wrong for AWS
gdal mdim convert /vsis3/aodn-cloud-optimised/satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_southernocean.zarr \
  out.tif --array name=sea_surface_temperature,view=[-1,:,:]
```

That one-day read (10000 × 2500, 29% valid) took 72 s here. Values come out
as float64 kelvin with scale/offset already applied. Chunks are 5 × 500 × 500
(time, lat, lon) for most satellite stores, so reading one day pulls five.
A full pass should walk time in 5-step blocks aligned to the chunks.

## 3. Gridded holdings that support trends

| family | stores | grid | domain | period |
|---|---|---|---|---|
| GHRSST L3S, single sensor (AVHRR) | 1d/3d/6d/1m × day/night/dn, Australia | 0.02° | 70–190°E, 70°S–20°N | 1992-03 → 2024/25 |
| GHRSST L3S, single sensor, **Southern Ocean** | 1d, 1m dn | 0.02° | 2.5–202.5°E, 77.5–27.5°S | 1992-03 → 2025-03 |
| GHRSST L3S, multi sensor | 1d/3d/6d/1m, Australia | 0.02° | as above | 2012-01 → 2026-11 |
| GHRSST L3S, multi sensor, **Southern Ocean** | 1d, 1m dn | 0.02° | as above | 2018-11 → 2026-11 |
| GHRSST L3C (NOAA-19, SNPP, Himawari-8) | per sensor, Aus + SO | 0.02° | as above | 2009 → 2025/26 |
| GHRSST L4 RAMSSA | daily | 1/12° | 60–190°E, 70°S–20°N | 2006-06 → 2026-11 |
| GHRSST L4 **GAMSSA** | daily | 0.25° | **global** | 2008-07 → 2026-11 |
| AusTemp (marine heatwave, cold spell, DHD, SSTA) | 14-day + daily | 0.02° | 110–164°E, 46–8°S (heatwave store 96–174°E, 48–8°S) | 2012 → 2026-11 |
| Ocean colour, MODIS Aqua | chl (OCI, OC3, GSM, Carder), Kd490, NPP (GSM, OC3), pico/nano fraction, optical water type, SST | 0.01° | 80–180°E, 60°S–10°N | 2002-07 → 2024-12 (Aqua is ending) |
| Ocean colour, VIIRS SNPP / NOAA-20 | chl (OCI, OC3, GSM), Kd490, OWT, SST | 0.0075° | 78–180°E, 60°S–12°N | 2012-01 / 2023-02 → 2026-11 |
| Gridded SLA + geostrophic currents (OceanCurrent GSLA) | DM + NRT | 0.2° | 57–185°E, 60°S–10°N | 1993-01 → 2026-11 |
| Altimeter wind | DM | 0.01° | 95–180°E, 49°S–1°N | 2017-10 → 2025-08 |
| HF radar (ACORN) | 9 sites, current (+ wave/wind at 4) | 1.5–7 km | coastal | 2007 → 2026 |

These products are close analogues of report sections 1.1–1.4 (SST, EAC, KE), 2.1–2.2 (chl, NPP),
2.4 (phenology), 2.6 (pico fraction), 3.1 (clarity, via Kd490) and 4.2
(heatwave).

Notes:

- The L3S stores carry `sst_count`, `sst_mean` and `sst_standard_deviation`
  per pixel. Each L3S pixel is therefore already a small sufficient-stats
  record of its L3C inputs.
- The Southern Ocean L3S carries `sea_ice_fraction`, which ties it to trend.ice.
- **Sensor seams**: the AVHRR single-sensor L3S ends in 2024/25 (NOAA-19 L3C
  stops 2025-06-08). The multi-sensor L3S starts in 2012 (Australia) or 2018 (SO).
  MODIS Aqua ends 2024-12, and VIIRS starts in 2012. Any trend through 2026
  must cross a seam. Each seam has an overlap of 6–13 years, so the offset
  across a join can be estimated per cell or region from the overlap. Keep the
  trend.* convention of never pooling sources.

## 4. GHRSST crossover: Australia, global, Southern Ocean

**Which GHRSST?** Every mention names the product, measured against the MUR
v4.1 COGs (<https://source.coop/ausantarctic/ghrsst-mur-v2>: JPL L4, 0.01°, global,
which is trend.sst's `ghrsst`). The IMOS/BoM products here are L3S clear-sky composites (0.02°,
regional) and BoM L4 analyses (RAMSSA, GAMSSA); see the table in `nci/README.md`. MUR pixels don't
nest in the 0.02° L3S lattice.

The IMOS L3S/L4 products are Bureau of Meteorology GHRSST (GDS2) products,
the same family as MUR (ghrsst-cogger) and OISST (trend.sst). So one
SST quantity can be compared nested from global to EEZ to park:

- **global**: OISST v2.1 (0.25°), GAMSSA (0.25°, IMOS bucket), MUR (0.01°).
  These are already partly in trend.sst at S2 L5.
- **Australian region**: RAMSSA (1/12°) and L3S Australia (0.02°, 1992 →).
- **Southern Ocean**: L3S Southern Ocean (0.02°, 2.5–202.5°E to 77.5°S).
  This covers the East Antarctic sector, the Kerguelen Plateau (Heard and McDonald
  Islands EEZ), Macquarie Island and the Ross Sea.

The first concrete test: put L3S-SO and GAMSSA into the existing S2 L5
registry next to OISST and MUR, then compare trends cell by cell over shared
periods. That needs no new geometry.

Caveat: all of these depend on AVHRR to some degree. Agreement between them
is a consistency check, not independent validation. The in situ record
(below) is the independent check.

## 5. Southern Ocean and Antarctic holdings in IMOS

| what | where |
|---|---|
| SOTS (Southern Ocean Time Series, ~47°S 142°E), 1997 → 2026 | `imos-data/IMOS/DWM/SOTS/` (+ `derived_products/gridded`); SOFS surface fluxes/properties Parquet |
| Antarctic deep-water arrays: POLYNYA1/2 (Mertz), TOTTEN1/2/3 | `imos-data/IMOS/DWM/DA/` |
| SOOP-CO2 underway: Aurora Australis (VNAA), **Nuyina (VMIC)**, Astrolabe (FASB/FHZI), Tangaroa (ZMFR), Investigator, Southern Surveyor | `imos-data/IMOS/SOOP/SOOP-CO2/`, `vessel_co2_*` Parquet |
| XBT IX28 (Hobart–Dumont d'Urville) + "Southern-Ocean" line label | `vessel_xbt_delayed_qc.parquet/SOOP_line_label=IX28/` |
| Seal-borne CTD (AATAMS: elephant and Weddell seals, report 4.8) | `animal_ctd_satellite_relay_tagging_*` Parquet (551 platforms) |
| Argo | `argo.parquet` (20,698 platforms, 32 GB) |
| SO-CPR, BASOOP bioacoustics (report 4.5) | `imos-data/IMOS/SOOP/SOOP-BA/`; SO-CPR via AADC (planktonr's `data-raw/AADC-00099_-_2025_data_update`) |

## 6. Regionalisation: EEZ, marine parks, bioregions

trend.* uses S2 level-5 cells (~290 km) and a dense, positional pixel→cell
mapping. That works for basin-scale questions, but marine parks are far
smaller than an L5 cell, and EEZ boundaries cut across cells. Proposed
approach:

- **Region tables beside cell tables.** For each source grid and each *region
  set* (EEZ zones, AMP parks, AMP zones, the six bioregional plan regions,
  IMCRA provincial bioregions, MEASO for the Southern Ocean), compute a sparse
  pixel → (region, coverage fraction) table once. controlledburn's coverage
  mode does this in O(perimeter) without a dense matrix. Accumulate per
  (region, date) `n, sumw, sumwx, sumwx2` with `w = cell area × coverage`
  (WGS84 cell area, which `R/03_coverage.R` computes per row; trend.* uses cos(lat), its spherical proportional form).
  The sums stay associative, and the daily run still needs no geometry.
- Boundary picks (details in `notes/boundaries.md`): GA AMB2020 EEZ (has the
  AAT and HIMI); the AMP layer (216 park-zones, current HIMI and Macquarie);
  CAPAD 2024 for state parks and GBRMP. The six STAR regions cover only
  Commonwealth waters: no GBRMP, state waters, Indian Ocean Territories, HIMI
  or AAT. Covering the whole EEZ therefore needs fill-in polygons, or IMCRA
  provincial instead.
- Within one set, regions must be disjoint for roll-ups to be exact
  (zone → park → network → EEZ). Sets that overlap (for example a park and a
  bioregion) are separate tables, never mixed.
- **Finer S2 levels for exploration** inside the EEZ. Mean cell size is about 36 km
  at L8, 9 km at L10 and 2.2 km at L12; L12 matches the 0.02° L3S pixel.
  At L10 the EEZ is roughly 1e5 cells, and 1e4 days × 4 doubles comes to tens
  of GB per product. L8 is a few GB.
- **Validation targets** from the report, to check that its numbers can be
  reproduced before extending them to 2026 and to parks:
  1.2 (SE box SST "~1 °C per decade" 1993–2016 from night L3S),
  2.1 (EEZ chl −0.5 %/yr, 2003–2019, MODIS OCI),
  2.2 (EEZ NPP −0.6 %/yr), and 3.1 (Secchi: no trend).

## 7. Next steps

1. ~~Boundaries into GeoParquet~~ done: `eez_legal`, `eez`, `star`, `imcra`,
   `amp` (`R/01_boundaries.R`, `notes/regions.md`). CAPAD 2024 is still to add.
2. ~~Coverage tables and area checks~~ done, on the **union** 0.02° lattice
   (L3S Australia ∪ Southern Ocean, 10000 × 4875), not just the Australia
   grid. Coverage areas match geodesic areas to < 1e-7 per set.
3. ~~One 5-day chunk block end to end~~ done for 2024-01-04..08
   (`R/05`–`R/08`, `notes/block_2024-01-04.md`).
   - Quality-filtered multi-sensor L3S agrees with MUR and OISST at S2 L5 about as well as they agree with each other (RMS ≈ 0.25–0.28 °C), with a warm offset of about +0.18 °C.
   - At L5, the choice of cells shifts an EEZ territory's mean by 0.1–0.5 °C. Next: a finer S2 level for EEZ work, alongside the exact region tables.
   - Read the NetCDF for the AVHRR Southern Ocean record (its Zarr is mostly empty), and mask by `sea_ice_fraction` before comparing with the L4s south of the ice edge.
4. Reproduce STAR 1.2 and 2.1, then extend them to 2026 with the sensor seams
   handled explicitly.
5. Add L3S-SO (with `sea_ice_fraction`) and GAMSSA to the S2 L5 registry
   next to OISST/MUR, joining trend.sst and trend.ice.
6. **NCI** (`nci/README.md`): join sh74 (IMOS/AODN mirror, `/g/data/sh74/IMOS_AODN`, not on THREDDS) and qm43 (BoM SST).
   Probe, inventories and byte identity done: sh74 is byte-identical to S3 apart from mirror lag and 1,178 stale 2026 files.
   Headers confirm IMOS switches from BoM fv02 to fv01 at 2023-01-01. On paired pixels fv01 − fv02 is −0.01 to −0.03 °C
   there (q4b), but the versions keep different pixels, which moves whole-window means by up to 0.25–0.36 °C in some years.
   Working choice: IMOS's record (fv02 to 2022, fv01 after) as the base, with 2023-01-01 as a documented seam.
   The in-situ daily sums of the whole L3S record (`nci/sums.pbs`) match R/07.
   - The first full run showed garbage in the source: a broken 1999 Southern AVHRR file, and the Ross Ice Shelf at
     52 °C, flagged as ice. So the sums now drop ice-flagged pixels and SST outside −2.5 … 40 °C.
   - Next: rerun them on Gadi into `sums-v2/`.
7. Biology refresh from the BGC_DB CSVs via planktonr. This is cheap and
   covers about half of the report's series.
