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
18. **The single-sensor Australia L3S Zarr is missing a chunk.** For 2024-01-04 and 2024-01-05 (the two days checked), one 500 × 500 chunk (100–110°E, 30–40°S) reads as empty, while IMOS's NetCDF has 92,238 and 78,261 valid pixels there. Everywhere else the Zarr and the NetCDF agree pixel for pixel, to float32 rounding (≤ 1.5e-5 K). So R/07's single-sensor block lacks those pixels, and the in-situ sums (`nci/sums.R`) have them. The multi-sensor stores match the NetCDF in pixel counts on both days.
    - Related to issue 9: on 2024-01-04 the Southern AVHRR NetCDF has data only at 79–172°E, 27.5–63.8°S, all inside the Australia window. So that day the Southern file adds nothing to a composite where Australia wins.
19. **A broken Southern AVHRR file: `L3S-1dS/dn/1999/19991004111000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn_Southern.nc`.**
    Its SST `add_offset` is 2.357e36 (other files: 270–300 K), and all 2.33 M valid pixels hold raw 0, so they decode to 2.4e36 °C.
    The sh74 copy is byte-identical to S3 (md5). In a composite where Australia wins, its 30,412 pixels outside the overlap are garbage.
    The single-sensor Zarr (issue 9) should be checked for that day too.
20. **Ice-flagged pixels in the AVHRR L3S hold made-up SST at high quality.**
    - On 1995-11-25 (Southern), 20,716 pixels at 67–78°S, 81°E–164°W (most on the Ross Ice Shelf, at 162–176°W) are at 52.0 °C (19 at 51.6),
      and 17,086 of them have quality 4–5. All are flagged as ice (`l2p_flags` bit 4).
    - So are 99% of the q4 pixels below −3 °C. Of the q4 pixels flagged as ice, 65% are in −2.5 … 36 °C (median −1.85).
    - Use `l2p_flags`, not `quality_level`, to leave ice out.
    - The multi-sensor L3S hardly ever sets the ice flag (0–6 pixels a day in 2024-01). It keeps a sub-freezing tail at the ice edge
      (q4 S2 cell means down to −4.5 °C), and `quality_level` 0–3 pixels go up to 40.2 °C and down to −4.3 °C.
    - The Continental AVHRR file for 1999-10-04 has quality < 4 pixels up to 52.0 °C (187 above 40 °C) and down to −8.8 °C.
    - The ice flag doesn't catch all of it. On 1997-05-05 (Southern), 115,912 pixels at 50.6–51.5 °C (71k at quality 4–5) are *not*
      flagged as ice, at 57–67°S, mostly 0–70°E (the May ice zone). In the sums, 6 more Southern days lose over half their pixels outside
      the overlap to a −2.5 … 40 °C test (1997-05/08, 1998-06/07).
21. **Whether BoM sets the ice flag depends on processing era, not on how much ice there is.**
    - Single-sensor AVHRR: Southern-window pixels outside the overlap are flagged as ice each September through 2012 (typically 2–6%,
      from 0.1% to 22%), and almost none from 2013-01.
    - Multi-sensor: almost none until 2025-04, then 0.5–4% a month from 2025-05.
    - So `l2p_flags` ice is not a consistent mask through time. Combined with issue 20, ice-zone pixels are sometimes flagged,
      sometimes present with made-up values, and sometimes perhaps just absent.
    - Counts from `nci/sums_check.csv` and the day logs.

22. **The AVHRR night L3S (`L3S-1d/ngt`, skin SST) has unflagged sub-freezing pixels in the winter ice zone, and some near-empty files.**
    - In the night sums (Continental window only), the −2.5 … 40 °C test drops 0.22% of the finite pixels that aren't flagged as ice, almost all
      of them cold. That's 0.005–0.09% a year in 1992–1998, 0.13–0.44% in 1999–2022, and 0.04–0.05% in 2023–2025 (fv01).
    - On 2004-07-15, 48,305 pixels are below −2.5 °C at 50–64°S, at every quality level (2–5). South of 60°S, 27% of the unflagged pixels
      are below −2.5 °C and 45% below −1.8 °C. On 2018-07-15 it's 10% and 22%, and on 2024-07-15 3% and 14%.
    - The ice flag is set on 0.3–1.9% of night pixels a year to 2012, and almost never from 2013 (as issue 21).
    - So below about 55°S in winter the night record holds ice or cloud as SST, in amounts that change with processing era.
    - 23 night files have no quality-4 pixel at all, and most are nearly empty (a typical night has about 4 million finite pixels).
      They hold 1,366–292,400 finite pixels. The 19 in 1992 lie only south of 36–59°S (1992-03-21: 4,557 pixels at 59–70°S, quality 2–3).
      The others are 1994-10-28, 1994-12-04, 1994-12-06 and 2013-04-06 (2,443 pixels at 50–63°S).
    - Counts from the day logs of `nci/sums.R` (job 184505429) and 27 files read from S3.

23. **Animal CTD Parquet (`animal_ctd_satellite_relay_tagging_delayed_qc`): impossible positions and inconsistent labels.**
    - 19,484 of 262,849 profiles are north of the equator (`R/13_animal_tracking.R`, `inventory/animal_ctd_by_species_site.csv`).
    - 15,088 of the 15,119 Weddell seal profiles labelled `Ross Sea` (2019–2020) sit at 32.5–36.6°N, −167.9 … −53.6°E.
    - 4,396 fur seal profiles (campaigns ct91, ct101 and ct110, 2012–2014, tagged at Montague Island, NSW) sit at
      18.8–22.2°N, 172.8–176.1°E. The same tags' other profiles are at 34–38°S, 150–152°E.
    - `species` spells one species two ways: "Southern ellie" (2004–2017) and "Southern elephant seal" (2018–). There
      is also "Weddel seal" (one tag). `location` holds campaign codes (`ct91`, `ct101`, `ct110`) for most fur seal
      tags.
    - The Parquet ends at 2024-02-22, while the location-QC `ctd` tables run to 2025 (delayed) and 2026 (real time).
