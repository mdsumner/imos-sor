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
