# Data issues seen in the IMOS/AODN stores

Seen 2026-11-17. Worth reporting upstream (AODN / aodn_cloud_optimised) once
confirmed.

1. **Partial append in `satellite_ghrsst_l3s_1day_daynighttime_multi_sensor_australia.zarr`.**
   - Most arrays have 5253 time steps; `time` and `sst_standard_deviation` have 5252.
   - `xarray.open_zarr()` fails: `ValueError: conflicting sizes for dimension 'time': length 5252 on 'sst_standard_deviation' and length 5253 ...`. zaro warns ("arrays disagree on the size of dimension(s): time").
   - The store's last time step is 2026-08-31, while the NetCDF source (`IMOS/SRS/SST/ghrsst/L3SM-1d/dn/`) runs to 2026-11-10. Updates appear to have stopped after a failed append.
2. **The Zarr copies lag the NetCDF archive for the AVHRR single-sensor L3S.**
   - The NetCDF ends 2025-06-06 (`L3S-1d/dn`, `L3S-1dS/dn`).
   - The Zarr ends 2024-11-08 (Australia, 1-day day+night) and 2025-03-01 (Southern Ocean).
   - For complete records, read the NetCDF tail.
3. **Typos in store names that are now fixed identifiers:** `satellite_diffuse_attenuation_coefficent_*`, `station_wireless_sensor_network_delayec_qc`.
4. **The AWS default region in this environment is not ap-southeast-2.** Pass `--region ap-southeast-2` or set `AWS_REGION` explicitly for `aws`, GDAL `/vsis3/` and s3fs.
5. **Grid registration:** `satellite_austemp_heatwave_14day` is half a cell (0.01°) off the 0.02° lattice that every other 0.02° IMOS store shares (centres at whole rather than odd hundredths).
6. **Chunking:** most satellite stores are chunked 5 × 500 × 500 (time, lat, lon), so a one-day read fetches 5 days. Walk time in chunk-aligned 5-step blocks.
7. **DCCEEW ArcGIS services:**
   - Published `AREA_KM2` collides with an added `area_km2`, because OGR field names are case-insensitive. `st_write()` then fails with "Field count reached: duplicate names present?" (GPKG too, not just Parquet).
   - `services.ga.gov.au/gis/rest` returns 403 to this client; the GA OGC services and the cloudfront zips work.

## Time axes (R/05_time_axes.R → inventory/time_axes.csv)

8. **Unsorted time is common: 42 of the 100 Zarr stores have time steps that go backwards.**
   - Examples: GSLA realtime (354), the HF radar realtime stores, GAMSSA (10), most daily L3S/L3C and VIIRS colour stores (1–15).
   - The pattern looks like late or backfilled days appended at the end. Australia multi-sensor L3S ends `… 2026-08-31, 2026-08-30, 2026-07-05, …, 2026-08-24, 2026-08-20`.
   - xarray tolerates this, but index-based reads (Zarr chunks, GDAL mdim, zaro) must map dates to indices explicitly. Never assume index order is time order, or that a 5-step chunk holds 5 consecutive days.
   - `satellite_austemp_sst-anomaly_australia` has 6 duplicate time values.
9. **The Southern Ocean single-sensor (AVHRR) L3S Zarr is mostly missing from 2010 on.**
   - Some dates that *are* present are empty: 0 valid pixels on 2024-01-04..08, 2008-09-15, 2013-02-18 and 2025-03-01, while the NetCDF for 2024-01-04 has 1.2 M. Other dates are full.
   - About 60 days a year are present; 245–306 days a year are absent, through 2024.
   - It also has 60 duplicated dates, and jumps from 2025-03-01 back to 2010-05-01 at index 7912.
   - The NetCDF source `IMOS/SRS/SST/ghrsst/L3S-1dS/dn/` is complete (365/366 files a year), so this is a conversion fault. Use the NetCDF for this record.
10. **Some gaps come from the source, not the conversion.**
    - Multi-sensor L3S NetCDF file counts: Southern Ocean 310 (2025) and 164 (2026 to 2026-11-09); Australia 323 (2025) and 278 (2026 to 2026-11-10).
    - The Zarr gaps match these, so 2025–2026 is an upstream outage. Trend work needs to treat those years' coverage explicitly.
11. **Metadata leftovers in the L3S Zarr stores.**
    - The multi-sensor Australia store's global `title` is "Temperature logger".
    - `valid_min`/`valid_max` are the packed-integer ranges (SST ±32767, `sses_bias` ±127), kept after the values were decoded to float32/float64 kelvin.
    - The global `summary` says "Skin sea surface temperature", while the variable is `sea_surface_foundation_temperature`.
    - Not harmful for reads, but don't trust these attributes for masking or labelling.
12. **The Australia and Southern Ocean multi-sensor stores disagree where their domains overlap**
    (70–190°E, 70–27.5°S; 2024-01-04..08).
    - None of the pixels valid in both are bit-identical.
    - The mean difference is 0.003 K, but single pixels differ by up to 9.5 K, and each store has pixels the other lacks.
    - The two domains are composited separately, so a stitched product needs a fixed precedence rule (here: Australia wins).

## Tools (for the hypertidy / GDAL side, not AODN)

- **zaro:**
  - `zaro_read(parallel = TRUE)` took 121 s for a 5-day block of one L3S variable (106 Blosc-lz4 chunks, 183 MB); gdalraster `mdim_read()` took 9 s, with identical values.
  - The installed 0.0.1.9030 has no `zaro_read_arrays()`, although the local README uses it.
- **gdalraster:** an intermittent crash during a loop of about a dozen `mdim_read()` calls on the same store, with `GDAL_NUM_THREADS=ALL_CPUS`:
  `Error: C stack usage 16657120997636 is too close to the limit`, then `terminate called after throwing an instance of 'Rcpp::LongjumpException'`.
  The same read alone succeeds, both with 1 thread and with all CPUs. Possibly R's error/warning path entered from a GDAL worker thread. Not yet reduced to a reprex.
- **GDAL Zarr driver:** `GDAL FAILURE 1: Invalid or unsupported format for dtype: |O` on opening stores with an object-dtype (vlen string) `filename` array. Harmless for numeric reads, but noisy.
- **GDAL Zarr driver:** it warns `Size of _ARRAY_DIMENSIONS[0] different from the one of shape` for the multi-sensor Australia store (issue 1), on every open.
13. **The IMOS L3S record changes BoM processing version at 2023-01-01.**
    - Matching sizes to BoM's qm43 archive (`nci/imos_vs_qm43.R`): IMOS's 1-day day+night files are BoM fv02 (reprocessing, product 2.0) to 2022-12-31 and fv01 (operational, product 01.0) from 2023-01-01.
    - BoM's fv02 runs further (Continental to mid-2025), but IMOS has not taken it up.
    - The Southern multi-sensor record 2012-01 → 2018-11 exists in BoM fv02 but not at IMOS.
    - Trend work needs to handle the seam or use qm43 fv02.
    - Confirmed by uuid for every file (`nci/headers_compare.R`). Before 2023 IMOS is mostly fv02, with inclusions:
      Continental AVHRR 2016-03..12 is a patchwork (fv01, unarchived runs); both AVHRR products 2014-09..12 are BoM's
      first fv02 run, which qm43 has since replaced; the first 37 days of Southern multi (2018-11..12) are an early run.
14. **The NCI mirror (sh74) doesn't replace files changed in place on S3.**
    - 1,178 SST files (all in 2026 folders) were rewritten on S3 on 2026-10-28; sh74 still holds the 6–22 October versions (sizes differ).
    - New files arrive 1.5–2 days after S3.
15. **S3 ETags mix three upload styles** (single PUT, 15 MiB s3cmd parts, 8 MiB aws-cli parts), so a byte-identity check must try all three (`nci/s3etag.py`).
    - With all three tried, the sh74 sample (3,713 files, 275 GB, first and last of every directory) is byte-identical to S3. The only differences are issue 14's stale files and the lag.
16. **BoM's qm43 GHRSST archive has its own quirks** (L3S 1-day day+night, both versions; `nci/README.md`, "Header results"):
    - 8 zero-byte fv01 files (2018-06, 2019-12) and a stray nested directory, `v02.0fv01/L3S-01day/dn/2018/L3S-01day/dn/2018/`.
    - 356 fv01 files (2006–2014) with `uuid = "yes"`.
    - `product_version` is written both ways: `1.0`/`2.0` (older files) and `01.0`/`02.0` (newer).
    - qm43 lacks 70 days that IMOS has, mostly multi-sensor 2026-08-11..26.
    - fv01 Continental files store `lon` wrapped at the antimeridian (70.01 … 179.99, −179.99 … −170.01), so the coordinate is not monotonic. fv02 and IMOS's copies run 70.01 … 189.99. GDAL gives the fv01 origin as −290.
    - The fv01 AVHRR files for 2021-06-25 (Continental and Southern) are 29 KB, header only, rewritten 2021-07-20. GDAL can't open the SST in them.
17. **BoM's fv02 is not one reprocessing.** All files say `product_version = 02.0`, but Continental 2023–2025 was made in 2025-09/10 and earlier years in batches back to 2014 (`nci/qm43_headers_by_year.csv`). In Continental AVHRR the batch boundary at 2023-01-01 shows as a step in `sses_bias` relative to fv01 (about −0.15 °C between late 2022 and early 2023, on paired pixels; `nci/README.md`, "Offset results"). Multi-sensor has no step there. Nothing in the files or the docs marks the boundary.
