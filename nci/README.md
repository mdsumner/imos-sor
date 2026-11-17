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
  1. Is it complete, and byte-identical to S3? `inventory.pbs` computes S3-style multipart ETags (8 MiB parts, checked against a real object) so files can be matched without downloading anything.

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
5. Copy `/g/data/jk72/$USER/imos-sor-probe/*` back into `data/nci/` here. Then run
   `Rscript nci/compare_inventory.R data/nci/inventory-sh74_IMOS_AODN_IMOS_SRS_SST_ghrsst.tsv.gz data/nci/etags-sh74_IMOS_AODN_IMOS_SRS_SST_ghrsst.tsv IMOS/SRS/SST/ghrsst`
   for presence and size per directory against S3, plus byte identity for the sample.

Then compute in situ with the container you use for trend.ice
(`/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif`): the 5-day block sums (R/07)
from `/g/data`, then whole records.

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
  The inventory ETags will test byte identity across the whole tree.
- **In situ is 3.7–7.4× faster.** About 2–3 s per file for 3 variables; at that speed decoding, not I/O, sets the pace.
- sh74 has the complete AVHRR Southern NetCDF (`L3S-1dS`) for these dates, which its AODN Zarr lacks.
- **fv02 multi-sensor keeps 16 % more q ≥ 4 pixels than fv01**, and its mean is 0.10 °C warmer (different pixel sets).

## Virtualising through THREDDS (raad.virtualize)

raad.virtualize harvests byte references from sources either over THREDDS
(`/vsicurl/`) or in situ (`/g/data`), then remaps `/g/data` to public URLs
in the published forms (as for BRAN). Public forms therefore need the data
to be reachable publicly. sh74 is not on THREDDS, so:

- **sh74 → S3 remap.** If the ETag check shows sh74 files are byte-identical to
  `s3://imos-data`, harvest in situ on Gadi (fast, local Lustre) with remap
  `/g/data/sh74/IMOS_AODN/` → `https://imos-data.s3.ap-southeast-2.amazonaws.com/`.
  The published store then points at AWS. That uses the store's remap rule exactly
  as designed, and avoids THREDDS altogether.

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

