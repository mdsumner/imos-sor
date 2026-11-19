# MEOP CTD profiles: S2 L5 cells, and a virtual store

The seal and turtle CTD profiles that IMOS publishes as MEOP-QC'd netCDF:
- `s3://imos-data/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/` (public)
- `/g/data/sh74/IMOS_AODN/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/` on NCI

Built by `py/meop_refs.py` (byte references and the profile index, about 2 minutes from outside AWS) and
`R/14_meop_cells.R` (position screen and S2 L5 cells). Tables: `inventory/meop_files.csv` and `inventory/meop_cells.csv`.
The survey of everything else is `notes/animal_tracking.md`.

## The files

- **564 files, one per tag, 267,386 profiles, 2004-01 → 2024-02.** There are two releases, with no tag in both:

  | release | files | profiles | levels | years | bytes |
  |---|---|---|---|---|---|
  | `MEOP-CTD_2017-10-01` (`*_prof.nc`) | 299 | 140,868 | 12–28, by tag (fixed SRDL levels) | 2004–2017 | 0.37 GB |
  | `IMOS-CTD_2024` (`*_hr1_prof.nc`; one file `MEOP-CTD_2023-12-01`) | 265 | 126,518 | 1,000 (1 dbar) | 2012–2024 | 7.57 GB |

- **Variables:** Argo-style `PRES`, `TEMP` and `PSAL`, each with `_ADJUSTED`, `_QC` and `_ADJUSTED_ERROR`, on
  (N_PROF, N_LEVELS). The per-profile ones are `JULD`, `LATITUDE`, `LONGITUDE`, `POSITION_QC` and `CYCLE_NUMBER`.
  - 97 of the 2024 files add `CHLA` and `LIGHT`, and 47 of those also `DOXY`.
  - 7 of the 2017 files add `CHLA`.
- **Layout: classic netCDF-3 (CDF-1).** Uncompressed and big-endian (`>f4`, `>f8`, `>i4`, `|S1`), with no record
  dimension.
  - So every variable is one contiguous byte range, and so is any run of whole profiles: profile *i* of a 2-D array
    starts at `begin + i × N_LEVELS × itemsize`.
  - kerchunk's netCDF-3 reader gives each variable's `begin` and size. Checked: the bytes at `TEMP_ADJUSTED`'s offset
    decode to the file's values exactly.
  - GDAL's netCDF driver has no `GetRawBlockInfo` for classic files (it returns nothing), so `raad.virtualize`'s
    `gdal` engine can't harvest them as it stands, and h5py doesn't apply.
- **The files change in place.** By last-modified date, 299 were written in 2017, 135 in 2024 and 130 in 2025.

## Positions and cells

- **19,484 positions are wrong:** north of the equator, all flagged good (`notes/issues.md` 23). They are in the
  Weddell seal campaigns ct150 and ct156 (Ross Sea, 2019–2020; 15,088 of their profiles) and the fur seal campaigns
  ct91, ct101 and ct110 (2012–2014; 4,396). Every species here is southern, so `pos_ok` is `lat < 0`. The profiles
  are kept and flagged, not moved.
- **247,902 profiles with good positions fall in 468 S2 L5 cells** (trend.sst's registry; of 6,144):
  - 441 of the cells, holding 99.4% of those profiles, are in the IMOS L3S lattice (R/06)
  - 303 cells are south of 50°S and 125 south of 60°S (107,391 profiles)
  - the median cell has 172 profiles; 292 cells have 100 or more, and 44 have 1,000 or more
- **The busiest cells** (cell centres) are off Davis (80.4°E 68.6°S, 19,040 profiles from 101 tags) and the
  Kerguelen plateau (71.4°E 49.8°S, 13,213 from 285 tags). Then come Prydz Bay (73.8°E 68.1°S), more of the
  Kerguelen plateau, the Adélie coast (140.5°E 67.1°S) and off Mirny (92.7°E 65.8°S).
- **By species:**
  - southern elephant seal: 203,467 profiles in 423 cells
  - Weddell seal: 40,643 (25,555 with good positions) in 17 cells
  - fur seal: 11,253 (6,857) in 13 cells
  - flatback turtle 7,042 in 18 cells, olive ridley turtle 4,981 in 23

## A virtual store (raad.virtualize → source.coop/ausantarctic)

Nothing has to be copied. The references point at IMOS's public objects. In raad.virtualize terms:

- **Store:**
  - The sources are the 564 files, recorded as harvested (`s3://imos-data/...`). Remaps go to https
    (`https://imos-data.s3.ap-southeast-2.amazonaws.com/...`) and to the sh74 paths for Gadi.
  - Each source has one chunk per array, at coordinate 0: offset `begin`, size `vsize`.
  - The harvest is a header parse. kerchunk works now, and a CDF-1 header reader is short. A
    `GetRawBlockInfo` for classic netCDF in GDAL's netCDF driver would let the `gdal` engine do it.
  - Because the files change in place, every source needs its size, mtime and ETag recorded, and `--recheck`
    on each harvest.
- **Canon 1, one group per tag:** each file's arrays as stored, one virtual chunk each, for all 564 files and both
  releases. It's faithful and simple. A reader picks tags from the profile index.
- **Canon 2, a profile cube for the 2024 release** (265 files, 1,000 levels): global arrays (profile, level) with
  chunks (1, 1000). This is pure arithmetic on canon 1's chunk rows: chunk *i* of source *s* is
  `begin_s + i × 4000` bytes (`>f4`), or `× 1000` for the `|S1` QC arrays.
  - 126,518 chunks an array: 15 arrays, or 30 with the `CHLA`, `DOXY` and `LIGHT` families.
  - The 1-D per-profile coordinates (time, lat, lon, cycle, platform, `pos_ok`, S2 cell) are small (about 1 MB
    each), so they're written as native arrays, not referenced.
  - `gdal mdim mosaic` can't plan this (N_PROF has no indexing variable), so the plan is the cumulative N_PROF of
    the sources, written directly, as `plan_static.py` and `plan_lift.py` do for their cases.
- **The 2017 release** has 8 different level counts (12–28), so it can't be one virtual array. It is either 8 small
  cubes, or a padded native copy (0.37 GB) next to the virtual 2024 cube.
- **Chunk size:** one profile per chunk means 4 KB reads. Bigger chunks would need each file to start on a chunk
  boundary, with its last, partial chunk written natively (Icechunk mixes native and virtual chunks). That's an
  optimisation for later.
- **STAC:** one item per tag. The bbox and time come from the good positions, not the files' `geospatial_*`
  attributes. The profile index (`data/animal/meop_profiles.parquet`: file, row, time, position, `pos_ok`, cell)
  goes with it as the catalog.

## NCI

None of this needs Gadi. The harvest reads headers only (about 2 minutes for all 564 files from here) and the
references point at public S3. sh74 is one more remap target, for jobs on Gadi. Gadi pays off for matching each
profile to its 0.02° L3S pixel on the same day (the L3S is on sh74). The cell-day comparisons need only the profile
index and the cell sums already in `data/` (L3S, MUR and OISST).
