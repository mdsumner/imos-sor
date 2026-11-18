# IMOS on NCI: what is there, what to join, how to probe

Checked 2026-11-17 from outside NCI (public THREDDS and GeoNetwork only). Everything about
`/g/data` itself is still to be confirmed with the probe below.

## Two NCI holdings that matter here

### sh74: the IMOS/AODN Data Mirror

- **Record:** GeoNetwork `f5176_5952_9436_5690`, DOI 10.25914/ek6n-5w78.
  - Created 2026-07-08, published 2026-11-04.
  - "An NCI-hosted mirror of datasets from IMOS … a replica of the IMOS data repository … updated daily."
  - Format NetCDF, CC BY 4.0, extent 45–168°E, 80–9°S, from 2007.
- **Path:** `/g/data/sh74/IMOS_AODN`.
- **Not on THREDDS:** `thredds.nci.org.au/thredds/catalog/sh74/...` is 404, and sh74 isn't in the root catalogue. Access is through Gadi or ARE only, and needs sh74 membership.
- **What the probe found** (2026-11-17, 19:42 AEDT):
  - `IMOS_AODN/` holds `IMOS/`, `wave_buoy_data/`, `IMOS_AODN_README.txt` and `license.txt`.
    It mirrors only the `IMOS/` prefix of `s3://imos-data`, not the AIMS, BoM, CSIRO, TERN, UNSW, … prefixes.
    `wave_buoy_data/` gathers the wave buoys of 11 providers.
  - `IMOS/` has the same facilities as S3 apart from `eMII` (S3's demos and test files), plus an extra `CO`.
    `CO` holds at least `diver_photoquadrat_qc_DwC.parquet`, one of the AODN cloud-optimised datasets.
  - **The daily L3S day+night file counts equal S3** for every year checked (L3S-1d, L3S-1dS, L3SM-1d, L3SM-1dS; 2010–2026), gaps included.
  - **Freshness:** the newest files are the same dates as on S3 (2026-11-10 Australia, 2026-11-09 Southern).
    They arrived about 1.5–2 days after their S3 `LastModified`: S3 2026-11-12 10:48 UTC, sh74 2026-11-15 01:17 AEDT.
  - **`IMOS/CO` holds a single dataset, `diver_photoquadrat_qc_DwC.parquet`**, although the README says
    data come "increasingly [in] cloud-optimised formats such as Parquet and Zarr". So for gridded work sh74
    is the NetCDF archive. `wave_buoy_data/IMOS/` holds `WAVE-BUOYS`.
  - **`IMOS_AODN_README.txt`** is v1.0, 01/07/26, by AODN. It gives licence and citation text, and says sh74 also has
    `admin/`, `mirror/` and `testing/` folders (outside `IMOS_AODN`; not user data). It describes the
    `IMOS_<Facility>_<Data-Code>_…_FV<nn>_…_C-<created>.nc` file-naming convention. The GHRSST files keep their GDS2
    names (`<time>-ABOM-L3S_GHRSST-…`), not that convention.
- **Remaining questions** (answered by `inventory.pbs` and `block_read.pbs`; jobs 184300275/76/78 submitted 2026-11-17):
  1. Is it complete, and byte-identical to S3? Answered below ("sh74 vs S3"): yes, apart from 8 files of mirror lag
     and 1,178 stale 2026 files; the 3,713-file ETag sample is byte-identical.

### qm43: Bureau of Meteorology satellite SST (the upstream of the IMOS L3S)

Public over THREDDS: `https://thredds.nci.org.au/thredds/catalog/qm43/ghrsst/...`, plus
`/g/data/qm43/ghrsst` on Gadi. Directory `v02.0fvNN` = GDS 2.0, file version NN.

- **`v02.0fv01` is IMOS's operational stream.**
  - 2024-01-04 Southern multi-sensor: all 8,154,386 valid values are identical to `s3://imos-data/.../L3SM-1dS/...`.
  - Both have `product_version 01.0`, with the same `date_created`.
  - Southern runs 2020 → now; the Continental equivalent is presumably there as well.
- **`v02.0fv02` is a BoM reprocessing (`product_version 02.0`) that IMOS does not publish.**
  - The 2024-01-04 file was created 2025-10-10 and is titled "geo-polar multiple-sensor"; references: Govekar et al.
  - Against IMOS's file for the same day (Continental AVHRR, quality ≥ 4 in both, 1.23 M px): mean +0.075 K, sd 0.274 K, 99 % |d| 1.21 K.
  - No values are identical, and coverage differs slightly.
  - Southern: AVHRR 1992–2022, **multi-sensor 2012–2022** (IMOS's S3 Southern multi-sensor only starts 2018-11).
  - Continental: 1992 → mid-2025.
  - It fills days missing from IMOS's S3 copy (Continental 2024: 365 AVHRR + 366 multi vs 354 + 350; 2023: 364 + 365 vs 355 + 355).
- **Housekeeping:** two `*.nc.pid*.ncap2.tmp` files are exposed in `Continental/L3S-01day/dn/2024/`.
- **Internal chunking** (good for byte-reference indexing):
  - Int16/Int8 packed, DEFLATE, one day per file.
  - Continental 1 × 1500 × 2000 (SST) and 1 × 2250 × 3000 (quality, bias); Southern 1 × 834 × 3334 and 1 × 1250 × 5000.
  - That is 9 or 4 chunks per variable per day, with no 5-day over-read as in the AODN Zarr, and half the bytes (the Zarr holds decoded float32/float64).

Per-year day+night file counts (qm43 / S3):

| year | Southern AVHRR | Southern multi | Continental AVHRR | Continental multi |
|---|---|---|---|---|
| 2010 | 363 / 364 | – / – | | |
| 2012 | 364 / 365 | 368 / – | 365 / 366 | 366 / 366 |
| 2015 | 365 / 365 | 365 / – | | |
| 2020 | 365 / 366 | 365 / 365 | 365 / 366 | 366 / 366 |
| 2022 | 364 / 365 | 360 / 365 | | |
| 2023 | 354 / 355 (fv01) | 355 / 355 (fv01) | 364 / 355 | 365 / 355 |
| 2024 | 351 / 350 (fv01) | 348 / 348 (fv01) | 365 / 354 | 366 / 350 |
| 2025 | 150 / 153 (fv01) | 308 / 310 (fv01) | 156 / 153 (fv02) | 181 / 323 (fv02; rest presumably fv01) |
| 2026 | – / – | 157 / 164 (fv01) | | |

So **"like for like" depends on the version.** If sh74 mirrors S3, it gives the IMOS
operational (fv01 = product 01.0) files: the same as AWS, but with local
filesystem access. For the longest and most complete SST record the better
source is probably qm43 fv02. That would be a third member of the
never-pooled family, beside IMOS fv01 and MUR/OISST, and the seam between
fv02 and fv01 (2022/2023 Southern, 2025 Continental) needs handling.

## Projects to join (my.nci.org.au → Projects → Find a project)

| project | what | why for imos-sor | status |
|---|---|---|---|
| **sh74** | IMOS/AODN Data Mirror | in-situ access to the whole IMOS archive | joined 2026-11-17 (log in again to pick up the group) |
| **qm43** | BoM satellite SST (GHRSST L2P–L3S, fv01 + fv02) | reprocessed L3S in situ; THREDDS works without membership | readable |
| gb6 | BRAN / OFAM | already used by raad.virtualize and bluelink | readable |
| jk72 | compute, scratch and storage | jobs (`-P jk72`), outputs in `/g/data/jk72/$USER`, temporary files in `/scratch/jk72/$USER`, the container | readable |
| zv2, gh70 | AGCD, ANUClimate 2.0 | terrestrial climate for the "Australia + AAT" footprint | not joined (later) |
| xu18, ka08, jw04 | GA Landsat / Sentinel-2 ARD and derivatives (DEA on NCI) | terrestrial and coastal (DEA) | readable |
| rr1 | GA elevation and bathymetry | AusBathyTopo etc. in situ | not joined (later) |
| ob53, fx3 | BARRA2 reanalysis, eReefs (GBR models) | drivers (wind, heat flux); the GBRMP gap in the STAR regions | ob53 readable; fx3 not joined |
| xp65 | ACCESS-NRI analysis environment (I believe; not verified here) | ACCESS-NRI tooling and catalogues | readable |

Status from `probe_login.sh`, 2026-11-17. ra22 (BoM satellite observations) is also readable; rv74 is not.

## Where things go on Gadi

Gadi `$HOME` is small, so keep the clone in `~` code-only (the repo is about 2 MB). Everything
these scripts write goes to jk72:

- **Persistent outputs:** `/g/data/jk72/$USER/imos-sor-probe/` (the default `OUTDIR` of all jobs).
- **Temporary job files:** `$PBS_JOBFS` and `/scratch/jk72/$USER/imos-sor` (scratch is purged when unused).
- **The R/ pipeline on Gadi:** make `data/` a symlink before running anything, e.g.
  `mkdir -p /g/data/jk72/$USER/imos-sor/data && ln -s /g/data/jk72/$USER/imos-sor/data ~/imos-sor/data`.
  This is the trend.* layout: clone in persistent software space, gitignored outputs elsewhere.
- **PBS logs** (`*.o<jobid>`) land in the submission directory. They're small.

## Steps

1. Log in to Gadi again so the new sh74 membership is active, then `bash probe_login.sh` (it should now list the sh74 tree).
2. sh74 inventory, SST tree, with ETags: `qsub -P jk72 -l storage=gdata/sh74+gdata/jk72 inventory.pbs`.
   `-v SUBDIR=IMOS` does the whole IMOS tree.
3. qm43 inventory, L3S/L3C/AusTemp, giving per-year counts by version (for the fv01/fv02 seams):
   `qsub -P jk72 -l storage=gdata/qm43+gdata/jk72 -v ROOT=/g/data/qm43/ghrsst,SUBDIR=.,ETAGS=0,PRUNE=qm43 inventory.pbs`
4. In-situ block read (qm43 fv01 + fv02 and the sh74 copy; timings and stats):
   `qsub -P jk72 -l storage=gdata/qm43+gdata/sh74+gdata/jk72 block_read.pbs`
5. ETags with all upload styles (md5, 8/15/16 MiB) for the same sample: `qsub -P jk72 -l storage=gdata/sh74+gdata/jk72 etags.pbs`, which writes `etags2-…tsv`.
6. Copy `/g/data/jk72/$USER/imos-sor-probe/*` back into `data/nci/` here. Then run
   `Rscript nci/compare_inventory.R data/nci/inventory-sh74_IMOS_AODN_IMOS_SRS_SST_ghrsst.tsv.gz data/nci/etags2-sh74_IMOS_AODN_IMOS_SRS_SST_ghrsst.tsv IMOS/SRS/SST/ghrsst data/nci/s3-IMOS_SRS_SST_ghrsst.tsv.gz`
   for presence and size per directory against S3, plus byte identity for the sample.
7. Headers of every 1-day day+night L3S file in sh74 and qm43 (about 75,000; `ncdump -h` only):
   `qsub -P jk72 -l storage=gdata/sh74+gdata/qm43+gdata/jk72 headers.pbs`, which writes `headers-l3s1d.tsv.gz`.
   Copy it back, then `Rscript nci/headers_compare.R` pairs each IMOS file with its BoM source by `uuid`.
8. fv01 vs fv02 offset in qm43, on every day both versions exist (about 7,900 day pairs over 4 products).
   First build the geometry kit here (`Rscript nci/offset_kit.R` → `data/nci/offset_kit.rds`, 3.6 MB) and copy it to
   `/g/data/jk72/$USER/imos-sor-probe/`. Then `qsub -P jk72 -l storage=gdata/qm43+gdata/jk72 offset.pbs`.
   - Outputs: one file per product-month in `offset/`. The job is resumable, so rerun the same command if it hits walltime.
   - Cost: job 184384481 took 2 h 23 min with 12 workers (27 CPU-hours, about 13 s per day per worker, 76 SU).
     PBS reported 64 GB used, which counts file cache; no worker died (all 291 product-months written).
   - Copy back, then run `Rscript nci/offset_summary.R` (12 s).
9. The IMOS L3S record as exact daily sums, in situ from sh74 (`sums.R`; R/07 for whole records):
   `qsub -P jk72 -l storage=gdata/sh74+gdata/jk72 sums.pbs`.
   - Covers multi-sensor (L3SM-1d + L3SM-1dS, 2012-01 → 2026-11) and single-sensor (L3S-1d + L3S-1dS,
     1992-03 → 2025-06), all / q4 / q4b, per S2 L5 cell (trend.sst schema), region set and whole domain.
     That's about 17,400 product-days in 579 product-months. It reuses `offset_kit.rds`, which is already in the probe directory.
   - Each day is composited on the union lattice as in R/07: the Continental file wins wherever it covers a pixel,
     and the Southern file fills the rest. Days with only one of the two files are kept, and the log says which.
   - Every variant drops pixels flagged as ice (`l2p_flags` bit 4) and SST outside −2.5 … 40 °C. The log counts
     what each window loses to each test, so the dropped pixels can be accounted for exactly.
     - The first run (job 184407123, output in `sums/`, copied here at 504/579 product-months) had no screen.
       Two problems in the source showed up in it (`notes/issues.md` 19–20).
       - The Southern single-sensor file for 1999-10-04 decodes to 2.4e36 °C.
       - Single-sensor AVHRR puts the Ross Ice Shelf at a fixed 52.0 °C with quality 4–5, flagged as ice.
         That gave 4,243 q4 S2 cell-days outside −3 … 40 °C, mostly in 1995–2005.
     - Both get into the region and domain sums, and no later filter on cells can take them out, so the run is
       redone with the screen into `sums-v2/`. `sums.R` refuses to add to a directory made with another screen,
       and the converter refuses to mix them.
     - Multi-sensor hardly ever sets the ice flag (0–6 pixels a day in 2024). It only has a sub-freezing tail:
       126 q4 cell-days at −3 … −4.5 °C, at the ice edge, 2012–2022.
   - The 20 sh74 files that S3 has since replaced (2026-09/10, multi-sensor) are computed but flagged. The S3 versions
     are 0.45–7 MB larger.
   - Tested here on 2024-01-04/05, with the files fetched from S3:
     - Multi-sensor matches R/07 (from the AODN Zarr) in every S2 cell and region: the same pixel counts, and means
       within 1.5e-5 °C (the Zarr's float32 rounding).
     - Single-sensor matches too, except for one 500 × 500 chunk that the Zarr lacks (`notes/issues.md` 18).
     - That comparison was without the screen. With it, each day's domain count drops by exactly the logged ice and
       range counts (multi 2024-01-04: 8,371 of 15.6 M, mostly below −2.5 °C at quality < 4). Cells the screen
       doesn't touch have bit-identical sums.
   - Cost: the first run (job 184407123, without the screen) took 3 h 37 min with 12 workers (40.5 CPU-hours, about 10 s per
     day per worker, 116 SU). All 579 product-months were written, with no failed days. The screen reads one more
     variable per window, so expect a little more. PBS reported 64 GB used, which counts file cache; about 3.5 GB per worker.
   - Output: `sums-v2/<product>/<YYYY-MM>.rds`, about 1.2 GB in all. Copy back with the usual rsync, then
     `Rscript nci/sums_to_parquet.R` writes R/07's per-day layout under `data/sums_imos/`
     (`s2l5/<product>_<variant>/<date>.parquet`, `regions/...`, and `days-<product>.csv`).
     It leaves out stale and failed days, and lists windows that lost more than half their pixels to the range test.
     To fill the stale days, run `sums.R` here on those files fetched from S3, and pass that output directory second:
     `Rscript nci/sums_to_parquet.R data/sums_imos data/nci/sums-v2 <s3 run>`.

All of these use the container you use for trend.ice (`/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif`).

## sh74 vs S3, and IMOS vs BoM versions (inventories from jobs 184300275/76)

All products here are BoM/IMOS GHRSST L3S/L3C/L4 (ABOM), not MUR.

**sh74 against `s3://imos-data/IMOS/SRS/SST/ghrsst`** (`compare_inventory.R`; listing made here 2026-11-17):

| | files |
|---|---|
| on S3 | 1,334,236 |
| on sh74 | 1,334,228 |
| same path, same size | 1,333,050 |
| S3 only | 8 (all added to S3 on 2026-11-17: the mirror's 1.5–2 day lag) |
| size differs | 1,178, **all in 2026 folders** (L3C/L3U VIIRS, L3SM 1/3/6-day, GAMSSA, RAMSSA) |

- The 1,178 were rewritten on S3 on 2026-10-28, while the sh74 copies date from 6–22 October.
  **The mirror brings in new files but has not replaced files changed in place on S3.**
  Per-file list: `nci/compare-IMOS_SRS_SST_ghrsst-files.csv`.
- **Where sizes match, the bytes match.** The ETag sample is the first and last file of every directory
  plus the three block files: 3,713 files, 275 GB, data years 1992–2026. **All 3,713 are byte-identical to S3**
  (`etags.pbs`, job 184319648, 41 min on one CPU; `nci/compare-IMOS_SRS_SST_ghrsst-etags.csv`).
  - The first attempt matched only 2,052, because it computed 8 MiB-part ETags only.
    The objects were uploaded three ways, and the S3 `LastModified` year tracks the style:

    | upload style | sample files | S3 LastModified |
    |---|---|---|
    | single PUT (ETag = md5) | 859 | 2016–2026 |
    | 15 MiB parts (s3cmd) | 1,326 | 2017–2018 |
    | 8 MiB parts (aws cli) | 1,528 | 2018–2026 |

  - So sh74 is a faithful copy of S3, except for the 8 lagging files and the 1,178 stale ones. Anything that
    treats sh74 as S3 (the remap below) must check sizes against an S3 listing first.

**Which BoM version IMOS holds** (`imos_vs_qm43.R`):
- Each IMOS 1-day day+night file is matched to the same-day qm43 file nearest in size.
- IMOS only edits attributes, so the median difference is +1.15 KB, while fv01 and fv02 files differ by megabytes.
  The edits: `Conventions`, `acknowledgment` wording, some variable comments, `quality_level:units`,
  `l2p_flags:flag_masks` → `flag_values`. Arrays and the per-file packing (`add_offset`, `scale_factor`) are unchanged.
- This is size-based. Per-year table: `nci/imos_vs_qm43_by_year.csv`.
- **Checking by header.** Each BoM file has its own global `uuid`, and IMOS keeps it, so the qm43 file with the same
  uuid is the IMOS file's source (`headers.pbs`, `headers_compare.R`).
  Per-year tables: `nci/imos_vs_qm43_headers_by_year.csv` and `nci/qm43_headers_by_year.csv`.

**Header results** (74,993 headers: 32,138 IMOS, 42,855 qm43; 2026-11-17):

| IMOS file's source | files | notes |
|---|---|---|
| qm43 fv02, same uuid | 27,468 | |
| qm43 fv01, same uuid | 4,272 | never an `RT/` file |
| no uuid match, same-day qm43 file with the same SST `add_offset` | 31 | same data, a later BoM run (IMOS's copy is created days after qm43's) |
| no match: a BoM run that qm43 no longer holds | 297 | see below |
| no qm43 file that day | 70 | mostly 2026-08-11..26 (multi-sensor) and 2025-11 |

- **The seam at 2023-01-01 is confirmed** for all four products.
  The 31,740 uuid pairs all agree in date and SST `add_offset`, and the size-based guess is right for every one of them.
  It was wrong for 64 files (the 2014 runs below), where an older run of the same version happened to be close in size.
- **Before 2023, IMOS is mostly but not purely fv02.** The inclusions:
  - *Continental AVHRR, 2016-03 → 2016-12*: a patchwork of 134 fv01 days (Mar–Sep), 67 days from runs qm43 doesn't
    hold (Aug–Dec), and 9 absent from qm43 (Oct). Plus one fv01 day in 2018-10.
  - *Both AVHRR products, 2014-09 → 2014-12* (about 92 days each): IMOS has BoM's first fv02 run (made 2014-11 → 2015-01);
    qm43 holds the remake from 2017-09.
  - *Southern multi-sensor, 2018-11-16 → 12-31* (37 days, the start of IMOS's record): an early run (made 2018-11 → 2019-01);
    qm43's fv02 for those days was made in 2021-04.
  - 12 scattered fv01 days in multi-sensor, 2021-04 → 2022-08 (11 Southern, 1 Continental).
- **BoM made fv02 in batches**, years after the fact (`qm43_headers_by_year.csv`):
  AVHRR 1992–2013 in 2014-10, 2014–2016 in 2017-09 (some 2019-08), 2017–2018 in 2019-08, 2019–2020 in 2022-06,
  2021–2022 in 2023-06, and Continental 2023–2025 in 2025-09/10. Multi-sensor follows a similar pattern from 2019-04.
  IMOS took up each batch for the years before 2023, but not the 2025 batch for 2023 onwards.
- **qm43 quirks** (BoM's archive):
  - 8 fv01 files are zero bytes (2018-06-18/20/21 AVHRR, 2019-12-04/05 multi, 2019-12-17/18/19 AVHRR).
  - 356 fv01 files (2006–2014) have `uuid = "yes"`.
  - Older files write `product_version` as `1.0` / `2.0`, newer ones as `01.0` / `02.0`.
  - `v02.0fv01/L3S-01day/dn/2018/L3S-01day/dn/2018/` is a stray nested copy (one zero-byte file).
  - fv01 Continental files store `lon` wrapped (70.01 … 179.99, −179.99 … −170.01); fv02 runs on to 189.99.
    GDAL reads the fv01 origin as −290 (= 70 modulo 360). IMOS's copies of fv01 files have `lon` unwrapped (to 189.99),
    so for fv01-era files IMOS also rewrites a coordinate array, not only attributes.

**fv01 vs fv02 offset** (`offset.R`, `offset.pbs`, `offset_summary.R`). For each day both versions exist,
d = fv01 − fv02 on the pixels valid in both, under each quality variant (all / q4 / q4b, each version with its
own `quality_level` and `sses_bias`). Exact sums are kept for the whole window, the region sets and S2 L5 cells,
together with each version's own-pixel sums. That separates the paired offset (calibration) from the
difference in which pixels each version keeps (selection), which together make up what a naive splice of the two
records would see.

**Offset results** (job 184384481, 7,876 of 7,878 day pairs; BoM ABOM L3S 1-day day+night, not MUR).
Tables: `nci/offset_by_region.csv` (every region set), `nci/offset_by_year.csv` (window, `eez_legal`, `star`),
`nci/offset_domain_monthly.csv`; per S2 L5 cell in `data/nci/offset_s2l5.csv` (not committed).
Whole window, q4b (the variant the trend record uses), d = fv01 − fv02 in °C:

| product | overlap in qm43 | days | paired offset | per year | day-to-day sd | pixel sd | naive splice | of which selection | fv01 pixels per fv02 pixel |
|---|---|---|---|---|---|---|---|---|---|
| Continental AVHRR | 2006-10 → 2025-06-06 (full from 2014) | 3,664 | +0.025 | −0.022 … +0.081 (2014–2025) | 0.058 | 0.31 | +0.117 | +0.093 | 0.96 |
| Continental multi | 2018-11-16 → 2025-06-29 | 2,177 | −0.000 | −0.013 … +0.024 | 0.018 | 0.17 | −0.038 | −0.038 | 0.89 |
| Southern AVHRR | 2020-01-01 → 2022-12-31 | 1,005 | +0.015 | +0.008 … +0.022 | 0.052 | 0.21 | +0.200 | +0.185 | 0.71 |
| Southern multi | 2020-01-01 → 2022-12-31 | 1,030 | +0.016 | +0.006 … +0.027 | 0.023 | 0.17 | +0.081 | +0.065 | 1.01 |

- **On the same pixels the two versions agree to a few hundredths of a degree.** The pooled q4b offset is within
  ±0.025 °C for every product, and in the six STAR regions for every product except Southern AVHRR Temperate East
  (−0.047). Without the bias correction (q4) Continental AVHRR is −0.056; every other product and variant is within ±0.031.
- **What a naive splice sees is mostly selection.** The two versions keep different pixels, and the own-pixel means
  differ by much more than the paired offset. Per year the naive difference reaches −0.25 °C (Continental multi
  2022), +0.36 °C (Southern multi 2020) and +0.27 °C (Southern AVHRR 2021, where fv01 keeps only 65% of fv02's
  pixels). Region means and domain means built from each version's own pixels would step by that much.
- **At S2 L5 most of the selection goes away.** Weighted by paired pixels, the middle 90% of cells have selection
  within −0.06 … +0.03 °C (Continental multi) and −0.003 … +0.05 °C (Continental AVHRR). The Southern products keep
  more: 10% of their paired pixels lie in cells where selection exceeds 0.1 °C. Paired offsets per cell, middle 90%:
  −0.018 … +0.014 (Continental multi), −0.027 … +0.106 (Continental AVHRR), −0.049 … +0.124 (Southern AVHRR),
  +0.001 … +0.041 (Southern multi).
- **Near Antarctica fv01 runs warm.** AATW and AATE (STAR outside regions) have q4b offsets of +0.02 to +0.15 °C in
  every product, largest in AVHRR, with naive differences up to +0.23 °C. For Heard Island (HIMI) the Continental
  AVHRR fv01 keeps only 7% of fv02's pixels, on 282 days.
- **The fv02 batch boundary at 2023-01-01 shows in Continental AVHRR.** fv02 for 2021–2022 was made in 2023-06 and
  for 2023–2025 in 2025-09/10. Across that boundary the mean `sses_bias` difference (fv01 − fv02, on paired pixels)
  flips from +0.07 … +0.08 °C (Oct–Dec 2022) to −0.05 … −0.16 °C (Jan–Jun 2023). The q4 offset goes from +0.030
  (2022 H2) to −0.083 (2023 H1), and the q4b offset from −0.026 to +0.016. fv01 is one continuous operational stream,
  so the change is most likely in fv02. Continental multi shows no such step (`sses_bias` difference +0.013 on both
  sides; q4b −0.014 → −0.008).
- **The IMOS seam** (fv02 to 2022-12-31, then fv01) on paired pixels, from the last six months of 2022, q4b:
  −0.026 °C Continental AVHRR, −0.014 Continental multi, −0.012 Southern AVHRR, −0.006 Southern multi. The larger
  ones equal one to three years of a 0.1 °C per decade trend. At region scale, the change in which pixels are kept
  is the bigger effect.
- Early Continental AVHRR overlap (2006, 2012–2013, 159 days) pairs poorly: fv01 has 4–78% of fv02's pixels there.
- 2 day pairs failed: the fv01 AVHRR files for 2021-06-25 (Continental and Southern) are 29 KB, header only
  (rewritten 2021-07-20). IMOS holds fv02 for that day.

| IMOS product | fv02 (BoM reprocessing) | fv01 (operational) | not matched |
|---|---|---|---|
| L3S-1d (Continental AVHRR) | 1992-03-21 → 2022-12-31 | 2023-01-01 → 2025-06-06 (plus 134 days in 2016) | 153 (2014, 2016) |
| L3S-1dS (Southern AVHRR) | 1992-03-21 → 2022-12-31 | 2023-01-01 → 2025-06-06 | 47 (2014) |
| L3SM-1d (Continental multi) | 2012-01-01 → 2022-12-31 | 2023-01-01 → 2026-11-10 | 6 |
| L3SM-1dS (Southern multi) | 2019-01-01 → 2022-12-31 | 2023-01-01 → 2026-11 | 37 (Nov–Dec 2018) |

- **The IMOS record switches processing version at 2023-01-01**, from BoM fv02 to fv01, for all four products. A trend over
  the last few years crosses it. Measured on the qm43 overlap periods (above), the paired step is about −0.01 to
  −0.03 °C (q4b), and the change of pixel selection is larger.
- **qm43 fv02 runs further than IMOS for Continental:** AVHRR to 2025-06-06 and multi-sensor to 2025-06-30.
  A single-version Continental record from 1992 (AVHRR) or 2012 (multi-sensor) to mid-2025 exists only in qm43.
- **qm43 fv02 has the Southern multi-sensor record from 2012-01-02, which IMOS lacks before 2018-11-16.**

**qm43 fv01/fv02 spans** (`qm43_seams.R` → `nci/qm43_l3s_seams.csv`; 1-day day+night):

| domain, sensor | fv02 | fv01 | days in both |
|---|---|---|---|
| Continental AVHRR | 1992-03-21 → 2025-06-06 (41 missing) | 2006 → 2025-06-06, sparse before 2014 | 3,691 |
| Continental multi | 2012-01-01 → 2025-06-30 (3 missing) | 2018-11-16 → 2026-11-10 (264 missing) | 2,208 |
| Southern AVHRR | 1992-03-21 → 2022-12-31 (41 missing) | 2020-01-01 → 2025-06-06 | 1,006 |
| Southern multi | 2012-01-02 → 2022-12-31 (18 missing) | 2020-01-01 → 2026-10-21 | 1,030 |

`v02.0fv01/L3S-01day/dn/RT/` holds a handful of real-time duplicates (2023–2025).

## Block read: in situ on Gadi vs off site (`block_read.R`, 2024-01-04..08)

These are the same five days, with SST, quality and bias decoded per file by GDAL's netCDF driver. All products are
BoM/IMOS GHRSST L3S (0.02° clear-sky composites), not MUR. In situ = `block_read.pbs`
(job 184300278, 4 cpus, `/g/data`); off site = this machine over qm43 THREDDS or IMOS S3.

| product | in situ, s/file | off site, s/file | speed-up | q ≥ 4 px/day | mean q ≥ 4 (°C) |
|---|---|---|---|---|---|
| qm43 Continental AVHRR fv01 | 2.29 | 8.44 (THREDDS) | 3.7× | 1,103,275 | 19.52176 |
| qm43 Continental AVHRR fv02 | 2.51 | 9.30 (THREDDS) | 3.7× | 1,101,583 | 19.57722 |
| qm43 Continental multi fv01 | 3.01 | 22.37 (THREDDS) | 7.4× | 10,659,282 | 21.42668 |
| qm43 Continental multi fv02 | 3.07 | 21.67 (THREDDS) | 7.1× | 12,369,203 | 21.53157 |
| qm43 Southern AVHRR fv01 | 2.19 | 8.65 (THREDDS) | 3.9× | 559,182 | 12.24328 |
| qm43 Southern multi fv01 | 2.55 | 17.11 (THREDDS) | 6.7× | 6,855,781 | 11.85548 |
| sh74 L3S-1d (Continental AVHRR) | 2.38 | 9.79 (S3) | 4.1× | 1,103,275 | 19.52176 |
| sh74 L3SM-1d (Continental multi) | 3.16 | – | – | 10,659,282 | 21.42668 |
| sh74 L3S-1dS (Southern AVHRR) | 2.15 | – | – | 559,182 | 12.24328 |
| sh74 L3SM-1dS (Southern multi) | 2.66 | 12.39 (S3) | 4.7× | 6,855,781 | 11.85548 |

- **sh74 = qm43 fv01 for all four products on all five days:** identical valid counts, q ≥ 4 counts and means.
  S3 also equals fv01 (identical values checked earlier), so all three hold the same data for this block.
  The ETag sample (above) confirms the files are byte-identical across the tree, not just this block.
- **In situ is 3.7–7.4× faster.** About 2–3 s per file for 3 variables; at that speed decoding, not I/O, sets the pace.
- sh74 has the complete AVHRR Southern NetCDF (`L3S-1dS`) for these dates, which its AODN Zarr lacks.
- **fv02 multi-sensor keeps 16 % more q ≥ 4 pixels than fv01**, and its mean is 0.10 °C warmer (different pixel sets).

## Virtualising through THREDDS (raad.virtualize)

raad.virtualize harvests byte references from sources either over THREDDS
(`/vsicurl/`) or in situ (`/g/data`), then remaps `/g/data` to public URLs
in the published forms (as for BRAN). Public forms therefore need the data
to be reachable publicly. sh74 is not on THREDDS, so:

- **sh74 → S3 remap.** sh74 files are byte-identical to `s3://imos-data` where sizes agree
  (ETag sample, above), so harvest in situ on Gadi (fast, local Lustre) with remap
  `/g/data/sh74/IMOS_AODN/` → `https://imos-data.s3.ap-southeast-2.amazonaws.com/`.
  The published store then points at AWS. That uses the store's remap rule exactly
  as designed, and avoids THREDDS altogether.
  - Guard: before harvesting, drop or re-harvest from S3 any file whose sh74 size differs from the S3 listing
    (the 1,178 stale 2026 files). Their byte offsets would not fit the S3 objects.

Candidates, most interesting first:

1. **qm43 `v02.0fv02` L3S-01day dn, Continental (1992 → 2025) and Southern
   (1992 → 2022; multi-sensor 2012 →), plus `v02.0fv01` from the seam onward.**
   - The reprocessed record isn't on AWS in any form.
   - Packed, day-chunked files make about 9 chunks per variable per day (≈ 430 k refs per product for SST, quality, bias and ice fraction).
   - The Southern files carry `sea_ice_fraction` (the trend.ice link).
   - Also worth adding: L3S-1month(-Southern) (a cheap check of the daily record), and L3C-01day-Southern per sensor (for seam work).
2. **IMOS AVHRR Southern Ocean L3S 1992–2025, from the S3 NetCDF** (`L3S-1dS/dn`).
   - Its Zarr is mostly empty after 2010, so a virtual store over the complete NetCDF replaces it.
   - This doesn't need NCI (sources over `/vsis3/` or https), but harvesting in situ from sh74 would be faster.
3. **IMOS multi-sensor L3S, Australia and Southern Ocean, from the S3 NetCDF.**
   This gives 1-day chunks and time-sorted placements, avoiding the Zarr stores' partial append, unsorted time and 5-day chunking.
4. **AGCD v1-0-4 (zv2) and ANUClimate 2.0 (gh70)**: terrestrial daily/monthly grids on THREDDS. They cover the land part of the `eez` footprint. Watch AGCD's CC BY-NC licence.
5. **eReefs (fx3/rr6)**: GBR hydrodynamic and biogeochemical model output. The GBRMP is the largest gap in the STAR regions, and the most heavily zoned marine park.
6. BARRA2 (ob53) surface fields, as marine-heatwave drivers.

Already done elsewhere:
- **BRAN (gb6)** is indexed at <https://source.coop/ausantarctic/ausantarctic-scratch/bluelink> (not its final home).
- **MUR** is COGged at <https://source.coop/ausantarctic/ghrsst-mur-v2>.

## GHRSST: which product, compared with the MUR COGs

"GHRSST" here always means a specific product. The MUR COGs are the reference point:

| product | maker, level | grid | coverage | notes |
|---|---|---|---|---|
| **MUR v4.1 (our COGs)** | JPL, **L4** gap-free analysis | 0.01°, 36000 × 17999, edges at x.xx5 (origin −179.995, 89.995) | global, 2002-06-01 → | foundation SST. Int16 COGs, scale 0.001, offset 25 → °C. trend.sst's `ghrsst` source |
| IMOS / BoM L3S (fv01) | BoM (ABOM), **L3S** clear-sky composite, gappy | 0.02°, edges on even hundredths | Australia 70–190°E, 70°S–20°N; Southern 2.5–202.5°E, 77.5–27.5°S | AVHRR 1992 →, multi-sensor 2012 → (Southern 2018 → at IMOS). On S3, sh74, qm43 `v02.0fv01` |
| BoM L3S (fv02) | BoM reprocessing, product 02.0, L3S | as fv01 | as fv01; Southern multi-sensor from 2012 | qm43 `v02.0fv02` only |
| RAMSSA / GAMSSA | BoM, **L4** analyses | 1/12° regional / 0.25° global | 60–190°E, 70°S–20°N / global | IMOS S3 L4/ and Zarr |

MUR pixels do **not** nest in the 0.02° L3S lattice. A 0.02° cell holds one whole MUR pixel and
halves of its neighbours, so comparing pixel for pixel needs resampling. The S2 and region sums
are unaffected, because every pixel goes in by its own centre or coverage.

