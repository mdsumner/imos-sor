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
- **Open questions** (answered by `probe_login.sh` and `inventory.pbs`):
  1. Is it the NetCDF archive `s3://imos-data` only, or also the cloud-optimised Zarr/Parquet?
  2. Is it complete, and byte-identical to S3? `inventory.pbs` computes S3-style multipart ETags (8 MiB parts, checked against a real object) so files can be matched without downloading anything.
  3. How fresh is it?

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
| **sh74** | IMOS/AODN Data Mirror | in-situ access to the whole IMOS archive | join (needed) |
| **qm43** | BoM satellite SST (GHRSST L2P–L3S, fv01 + fv02) | reprocessed L3S in situ; THREDDS works without membership | join (recommended) |
| gb6 | BRAN / OFAM | already used by raad.virtualize and bluelink | probably held |
| jk72 | your compute and storage project | jobs, `/g/data/jk72/$USER`, the container | held |
| zv2, gh70 | AGCD, ANUClimate 2.0 | terrestrial climate for the "Australia + AAT" footprint | later |
| xu18, ka08, jw04 | GA Landsat / Sentinel-2 ARD and derivatives (DEA on NCI) | terrestrial and coastal (DEA) | later |
| rr1 | GA elevation and bathymetry | AusBathyTopo etc. in situ | later |
| ob53, fx3 | BARRA2 reanalysis, eReefs (GBR models) | drivers (wind, heat flux); the GBRMP gap in the STAR regions | later |
| xp65 | ACCESS-NRI analysis environment (I believe; not verified here) | ACCESS-NRI tooling and catalogues | check |

`probe_login.sh` reports which of these you can already read.

## Steps

1. Join **sh74** (and qm43). Approval can take a little while.
2. On Gadi: `git clone https://github.com/mdsumner/imos-sor.git` (a private repo: use a token or `gh auth login`), then `cd imos-sor/nci`.
3. On a login node: `bash probe_login.sh`, which writes `~/imos-sor-probe/login-<date>.txt`.
4. `qsub -P jk72 -l storage=gdata/sh74+gdata/jk72 inventory.pbs`. The default is `SUBDIR=IMOS/SRS/SST/ghrsst`; `-v SUBDIR=IMOS` does the whole IMOS tree.
5. Copy `/g/data/jk72/$USER/imos-sor-probe/*` back into `data/nci/` here, then run
   `Rscript nci/compare_inventory.R data/nci/inventory-IMOS_SRS_SST_ghrsst.tsv.gz data/nci/etags-IMOS_SRS_SST_ghrsst.tsv IMOS/SRS/SST/ghrsst`.
   This gives presence and size per directory against S3, plus byte identity for the sample.

Then compute in situ, using the container you already use for trend.ice
(`/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif`):
- rerun the 5-day block (R/07) against `/g/data/sh74` NetCDF and `/g/data/qm43` fv02;
- then whole records.

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

(BRAN, gb6, is already done.)
