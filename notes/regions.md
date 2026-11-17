# Region sets and coverage tables

Built 2026-11-17 by `R/01_boundaries.R`, `R/02_lattice.R`, `R/03_coverage.R`
and `R/04_product_coverage.R`. Geometry and coverage tables live in `data/`
(gitignored, regenerable in about 2 minutes). The checks are committed in
`boundaries/`.

## Region sets

Each set is used on its own. Regions within a set are disjoint (overlap
≤ 0.8 km², from the Torres Strait hole-fill), so sums over a set's regions
are exact. Sets are never mixed.

| set | regions | km² | definition |
|---|---|---|---|
| `eez_legal` | 9 | 10,075,944 | GA AMB2020 EEZ as amended by the Perth Treaty 1997 (GA's recommended depiction), 12–200 nm as published |
| `eez` | 9 | 18,867,726 | same 9 territories, everything inside the 200 nm limit: EEZ + territorial sea, holes filled. **Includes land and internal waters.** Each product's own mask decides what is water. This set is also the footprint for later land/sea overlap work |
| `star` | 15 | 18,867,726 | the 6 Commonwealth Marine Regions used by STAR 2020, clipped to `eez`, plus 9 "outside regions: <territory>" fill-ins (GBRMP + state waters + land for MLD; all of CI, CKI, HIMI, AATW, AATE, TST) |
| `imcra` | 41 | 8,637,591 | IMCRA v4.0 provincial bioregions. 115,022 km² lies outside `eez`. Covers neither HIMI nor the AAT (93.4–171.8°E) |
| `amp` | 216 | 4,201,018 | Australian Marine Parks, one region per park zone. Rolls up to park (`RESNAME`), network (`NETNAME`) or IUCN category (`ZONEIUCN`) by summing |

Territories (`NOBJNM`):
- MLD: mainland, including Tasmania, Lord Howe and Ashmore/Cartier
- TST: Torres Strait
- CI: Christmas Island
- CKI: Cocos (Keeling)
- NI: Norfolk
- MAC: Macquarie
- HIMI: Heard and McDonald
- AATW / AATE: Australian Antarctic Territory, west and east of Adélie Land

Area checks (`boundaries/regions.csv`):
- IMCRA and AMP geodesic areas equal the published `AREA_KM2`.
- The six STAR regions match the bioregional plan figures (Coral Sea 989,836 km²; SW 1.29 M; NW 1.07 M; SE 1.63 M; TE 1.47 M; N 0.63 M).
- `eez` MLD minus Australian land (~7.69 M km²) gives ≈ 6.87 M km², the same as the VLIZ v12 mainland EEZ.

## The 0.02° lattice

`boundaries/lattice.csv`: all of the 0.02° GHRSST grids below sit on **one global lattice**, with cell centres at odd hundredths (float32 deviation ~1e-5):
- L3S Australia, single and multi sensor
- L3S Southern Ocean, single and multi sensor
- AusTemp

| grid | cols × rows | extent (edges) | offset into union (col, row) |
|---|---|---|---|
| union | 10000 × 4875 | 2.5–202.5°E, 77.5°S–20°N | 0, 0 |
| L3S Australia | 6000 × 4500 | 70–190°E, 70°S–20°N | 3375, 0 |
| L3S Southern Ocean | 10000 × 2500 | 2.5–202.5°E, 77.5–27.5°S | 0, 2375 |
| AusTemp | 2685 × 1890 | 110–163.7°E, 46–8.2°S | 5375, 1410 |

All are stored north-up. One set of coverage tables on the union grid
serves every product on the lattice: subtract the offsets.

Every other 0.02° store in the bucket (all L3S/L3C variants, AusTemp DHD and SSTA)
sits on the same lattice. **One exception: `satellite_austemp_heatwave_14day`**
(96–174°E, 48–8°S) has centres at whole hundredths, half a cell off. It
needs its own burn, or resampling, before it can share the tables.

## Coverage tables

`data/coverage/<set>.parquet`: `region_id, row, col_start, col_end, fraction`.
Rows/cols are 1-based on the union grid, rows counted from the top. Interior
runs have fraction 1. Boundary cells get their exact fraction (controlledburn
coverage mode; 0.1 s per set). Cell areas use the WGS84 ellipsoid.

Check (`boundaries/coverage_check.csv`): Σ fraction × cell area against the
geodesic polygon area.
- Whole sets agree to |rel| < 1e-7.
- Single regions agree to ≤ 4e-6, apart from tiny pieces: 3e-5 for a 0.05 km² Cocos zone, 8e-4 for a 39 km² sliver.
- 3 of the 216 AMP zones are smaller than one pixel (~4 km²). Their statistics come only from pixel fractions.

## Which products cover which territories

`notes/product_coverage.md` (and `boundaries/product_coverage.csv`) gives, for every
gridded store, the % of each EEZ territory and AMP network inside its
domain. Domain only: cloud, ice and land are not counted. Main points:

| product family | HIMI | AATW | AATE | MAC | CI/CKI |
|---|---|---|---|---|---|
| L3S/L3C Australia (0.02°) | 85.9 | 72.2 | 100 | 100 | 100 |
| L3S/L3C Southern Ocean (0.02°) | 100 | 100 | 100 | 100 | 0 (MLD 51 %) |
| RAMSSA L4 (1/12°) | 100 | 81.9 | 100 | 100 | 100 |
| **GAMSSA L4 (0.25°, global)** | 100 | 100 | 100 | 100 | 100 |
| GSLA (0.2°) | 100 | **0** | **0** | 100 | 100 |
| Ocean colour MODIS Aqua (0.01°) | **0** | **0** | **0** | 100 | 100 |
| Ocean colour VIIRS (0.0075°) | 7.8 | **0** | **0** | 100 | 100 |
| AusTemp (0.02°) | **0** | **0** | **0** | **0** | 0 / partial |
| Altimeter wind (0.01°) | **0** | **0** | **0** | **0** | 100 / 82 |

- Heard Island misses out of every IMOS ocean colour, heatwave and wind
  product. Its EEZ is only partly in the Australian SST domain, which starts
  at 70°E.
- "Australia + AAT" at 0.02° = L3S Australia ∪ L3S Southern Ocean on the
  shared lattice. Together they cover all nine territories completely.
  GAMSSA is the only single IMOS product that does, at 0.25°.
- For ocean colour around HIMI and the AAT, a global product is needed
  (ESA OC-CCI, as in trend.chl, or NASA L3).
