# Trends and status from the in-situ L3S sums (R/09)

These are BoM/IMOS ABOM GHRSST L3S 1-day composites at 0.02°, not MUR.
- **single-sensor:** AVHRR day+night (SSTfnd), 1992-03 → 2025-06.
- **multi-sensor:** day+night (SSTfnd), 2012-01 → 2026-11.
- **single-sensor night** (`single_night`): AVHRR night only, **skin** SST, Continental window only, 1992-03 → 2025-06.
  STAR 1.2 used it.

The input is the daily sums from `nci/sums.R`. Ice-flagged pixels and SST outside −2.5 … 40 °C have already been dropped (`nci/README.md`, step 9).
The script is `R/09_trends.R`, which runs in about 3 minutes. Its committed outputs are `trends/region_trends.csv`,
`trends/cell_trends_q4.csv`, `trends/region_status.csv` and `trends/region_monthly_q4.csv.gz`.
The finer S2 levels in the South-east come from `R/10_fine_trends.R` (about 6 minutes), with outputs
`trends/fine_se_region_trends.csv` and `trends/fine_se_cell_trends_q4.csv`.

## Method

- **Monthly sums:** daily sums add up to monthly sums for each S2 L5 cell and each region.
- **Climatology:** calendar-month means over each product's base years. Single-sensor uses 1993–2022, needing at least
  15 of the 30 years. Multi-sensor uses 2013–2022, needing at least 7 of 10. Night uses the single-sensor base.
  - Single-sensor can't use 2013–2022: its coverage collapses after 2012 west of about 90°E in the south, and
    in the Southern file outside the overlap. With that base, nearly half the cells south of 40°S (247 of 549)
    lose their whole record, HIMI included.
  - Trends don't depend on the base. To compare the two products, re-centre them on the years they share.
- **Which months count:** a month counts if its coverage is at least a fifth of that cell's or region's median coverage
  (cells also need at least 30 pixel-days). A fixed cutoff would drop the coast, cells that are partly land, and the
  sparse early AVHRR years.
- **Anomalies first (the "cell" method):**
  - Each cell's monthly anomaly is taken against its own climatology.
  - A region's anomaly is the mean of its cells' anomalies, weighted by the area of the region in each cell. That area
    is exact on the 0.02° lattice, capped at the cell's ocean area, where ocean area is the most of the cell ever seen in one day.
  - A month needs valid anomalies over at least half of the region's observable area (the cells with a climatology for
    that calendar month).
- **Trends:** ordinary least squares on monthly anomalies. The standard error is inflated for lag-1 autocorrelation
  (r1 ≈ 0.6–0.8). Ranges below are 95% intervals. A trend needs at least 80% of its period's months.

## Anomalies first, not region means

The region's own monthly mean (the "direct" method) is exact. But which part of the region was clear of cloud
changes from month to month, and in a region with a strong north–south gradient that dominates the trend.

| region (single, q4, 1993–2016, °C/decade) | anomalies first | direct region mean |
|---|---|---|
| Coral Sea | +0.21 | +0.21 |
| North | +0.27 | +0.27 |
| North-west | +0.27 | +0.24 |
| South-east | +0.21 | −0.31 |
| South-west | +0.11 | +0.00 |
| Temperate East | +0.14 | +0.12 |
| whole domain | +0.16 | −1.32 |

Multi-sensor's whole domain over 2013–2024 is +0.13 with anomalies first but −0.79 direct. That is because it has no
Southern data before 2018-11, so the direct mean drops when the cold south comes in. **Use anomalies first for every trend.**

## STAR regions (q4, anomalies first, °C/decade)

| region | single 1993–2016 | single 1993–2024 | single 2013–2024 | multi 2013–2024 |
|---|---|---|---|---|
| Coral Sea | +0.21 [+0.03, +0.40] | +0.18 [+0.07, +0.29] | +0.32 [−0.09, +0.72] | +0.54 [+0.10, +0.97] |
| North | +0.27 [+0.05, +0.49] | +0.22 [+0.09, +0.35] | +0.02 [−0.49, +0.53] | +0.07 [−0.43, +0.56] |
| North-west | +0.27 [+0.11, +0.43] | +0.17 [+0.07, +0.28] | −0.18 [−0.61, +0.25] | −0.14 [−0.63, +0.35] |
| South-east | +0.21 [+0.06, +0.37] | +0.16 [+0.07, +0.25] | −0.15 [−0.47, +0.16] | −0.11 [−0.46, +0.24] |
| South-west | +0.11 [−0.15, +0.38] | +0.01 [−0.14, +0.15] | −0.28 [−0.80, +0.24] | −0.21 [−0.75, +0.34] |
| Temperate East | +0.14 [−0.01, +0.29] | +0.10 [+0.00, +0.20] | −0.14 [−0.54, +0.26] | +0.05 [−0.42, +0.53] |
| whole domain | +0.16 [+0.11, +0.22] | +0.13 [+0.10, +0.17] | +0.03 [−0.11, +0.16] | +0.13 [−0.04, +0.29] |

- **Over 2013–2024 both products agree within the intervals.** Twelve years is too short to tell a trend from the
  ENSO-driven ups and downs.
- **The variant matters little** (single, 1993–2016): the all / q4 / q4b trends are within 0.07 of each other in every
  region. q4 is the lowest in most regions, and q4b is highest in the south (South-east +0.28, South-west +0.18).
- **The 2023-01-01 seam (fv02 → fv01) is small:** fv01 − fv02 on paired pixels in 2022 is within ±0.045 °C for every STAR
  region (`seam_2022`; the largest is North at +0.044). A step that size moves a 1993–2024 trend by less than 0.01 °C/decade, and a 2013–2024 trend
  by up to about 0.03.

## Against STAR 1.2

STAR 1.2 reports "~1 °C per decade in the SE; none on the west coast", for 1993–2016, from night L3S.
Night against day+night, single-sensor q4, anomalies first (°C/decade):

| region | night 1993–2016 | day+night 1993–2016 | night 1993–2024 | night 2013–2024 |
|---|---|---|---|---|
| Coral Sea | +0.26 [+0.06, +0.46] | +0.21 [+0.03, +0.40] | +0.27 [+0.15, +0.39] | +0.54 [+0.12, +0.96] |
| North | +0.30 [+0.07, +0.52] | +0.27 [+0.05, +0.49] | +0.29 [+0.16, +0.42] | +0.25 [−0.24, +0.74] |
| North-west | +0.26 [+0.08, +0.44] | +0.27 [+0.11, +0.43] | +0.19 [+0.07, +0.30] | −0.09 [−0.57, +0.38] |
| South-east | +0.23 [+0.08, +0.38] | +0.21 [+0.06, +0.37] | +0.20 [+0.11, +0.29] | 0.00 [−0.32, +0.32] |
| South-west | +0.11 [−0.13, +0.35] | +0.11 [−0.15, +0.38] | +0.05 [−0.08, +0.18] | −0.11 [−0.59, +0.36] |
| Temperate East | +0.13 [−0.04, +0.30] | +0.14 [−0.01, +0.29] | +0.14 [+0.03, +0.24] | +0.03 [−0.39, +0.44] |

- **Night doesn't change the answer for 1993–2016.** Night and day+night agree within 0.05 °C/decade in every STAR region.
  Night `all` is up to 0.06 higher than q4, and q4b is within 0.04 of q4.
- **West coast:** South-west is +0.11 at night too, and its interval spans zero. That agrees with STAR.
- **South-east:** +0.23 [+0.08, +0.38] at night. The fastest S2 L5 cells are the same as for day+night, east of
  Tasmania and in the southern Tasman: 151.8°E 42.6°S is +0.53 [+0.31, +0.75] at night (+0.49 day+night), then
  149.7°E 44.5°S +0.47, 148.8°E 41.7°S +0.47 (partly land), 149.8°E 39.7°S +0.45 and 152.8°E 40.5°S +0.45.
- **So ~1 °C/decade isn't reached at L5, by night or by day+night.** L5 cells are about 290 km across, so a narrower
  hotspot would be smoothed out. The finer levels below don't reach it either.
- Night's later trends are higher than day+night's: by 0.01–0.09 °C/decade over 1993–2024 and 0.09–0.23 over
  2013–2024, because of the step below. Night's whole domain is the Continental window only, so it isn't compared with
  the day+night whole domain (night: 1993–2016 +0.21 [+0.11, +0.30], 1993–2024 +0.20 [+0.15, +0.25]).

## Finer S2 levels in the South-east (R/10)

The STAR South-east region at S2 L8 (about 33 km at 42°S), L7 (~70 km), L6 (~140 km) and L5 (~290 km). The L8 sums
cover every pixel of the 45 L5 cells that touch the region (`nci/README.md`, step 10; job 184559983). Each coarser
level is the exact sum of its children, and at L5 every cell and region trend equals R/09's (difference 0). Same
method as R/09, q4, °C/decade.

Fastest cells, among cells at least half in the region:

| product, period | L8 | L7 | L6 | L5 |
|---|---|---|---|---|
| night 1993–2016 | +0.71 [+0.48, +0.95] | +0.70 [+0.46, +0.94] | +0.61 [+0.36, +0.86] | +0.53 [+0.31, +0.75] |
| day+night 1993–2016 | +0.64 [+0.42, +0.87] | +0.63 [+0.40, +0.86] | +0.56 [+0.33, +0.79] | +0.49 [+0.27, +0.71] |
| night 1993–2024 | +0.55 [+0.34, +0.77] | +0.53 [+0.31, +0.74] | +0.48 [+0.33, +0.63] | +0.44 [+0.26, +0.62] |
| day+night 1993–2024 | +0.48 [+0.30, +0.66] | +0.45 [+0.25, +0.65] | +0.41 [+0.24, +0.58] | +0.37 [+0.19, +0.56] |

- **No cell reaches ~1 °C/decade over 1993–2016, at any level, by night or by day+night.** The fastest is +0.71 at
  night in the L8 cell at 151.3°E 42.9°S, in the Tasman Sea about 250 km off the east coast of Tasmania. Its interval
  runs to +0.95. Night has 170 of 1,190 L8 cells at +0.5 or more, and none at +0.8. Day+night has 90 of 1,424.
- **The hotspot is one place.** The fastest cells at L8, L7 and L6 are all in the same patch, 150.4–152.2°E,
  42.4–43.6°S, inside the L5 cell (151.8°E 42.6°S) that was fastest in R/09. Smaller cells raise its peak from +0.53
  to +0.71. The L7 peak is nearly the L8 peak, so the fast patch is at least an L7 cell (~70 km) wide.
- **Over 1993–2016 most cells warm:** the median L8 cell is +0.31 at night and +0.22 by day+night. 795 of 1,190 night
  cells have an interval above zero.
- **2013–2024 is too short:** medians are near zero or negative. Two night L8 cells reach +0.8 or more (+0.85 at
  144.9°E 45.8°S), and the fastest cell's interval spans zero at every level.
- **The region trend rises a little with finer cells.** Night 1993–2016 is +0.23 [+0.08, +0.38] at L5, +0.27 at L6
  and L7, and +0.28 [+0.12, +0.43] at L8. Day+night goes from +0.21 to +0.23. Later periods move by 0.00–0.03.
  - This isn't because L5 cells reach outside the region. The 45 L5 cells cover 3.3 million km², twice the region,
    but weighting the L8 anomalies by the L5 footprint gives +0.27, nearly the L8 value (R/10's footprint test;
    day+night +0.23, the L8 value).
  - So the change comes from the anomalies themselves: which pixels and months each cell's mean and climatology are
    made from. An L5 cell's monthly mean mixes whatever parts of it were clear. Night probably gains more than
    day+night because it has fewer passes (not checked). Here L5 region trends are up to 0.05 °C/decade below L8's.

## Single-sensor, multi-sensor and night

Both products are re-centred on 2013–2021. The table shows single − multi annual anomaly, in °C:

| year | domain | Coral Sea | North | North-west | South-east | South-west | Temperate East |
|---|---|---|---|---|---|---|---|
| 2012 | −0.03 | −0.01 | −0.01 | −0.11 | −0.02 | −0.04 | −0.03 |
| 2013 | +0.07 | +0.02 | −0.10 | −0.08 | +0.03 | +0.02 | +0.06 |
| 2014 | +0.04 | +0.04 | +0.01 | −0.03 | +0.02 | +0.03 | +0.01 |
| 2015 | −0.02 | +0.03 | −0.02 | −0.03 | +0.03 | +0.03 | +0.03 |
| 2016 | +0.02 | +0.01 | +0.06 | −0.01 | −0.03 | −0.04 | −0.05 |
| 2017 | +0.03 | +0.04 | +0.02 | +0.02 | −0.00 | −0.01 | −0.02 |
| 2018 | −0.04 | +0.04 | −0.00 | +0.03 | −0.09 | −0.03 | −0.02 |
| 2019 | −0.09 | −0.09 | +0.10 | +0.07 | +0.04 | +0.01 | +0.00 |
| 2020 | −0.02 | −0.02 | −0.06 | +0.05 | −0.00 | −0.00 | +0.01 |
| 2021 | +0.00 | −0.08 | −0.02 | −0.02 | +0.02 | +0.00 | −0.03 |
| 2022 | +0.02 | −0.20 | −0.09 | −0.09 | −0.01 | −0.06 | −0.12 |
| 2023 | −0.07 | −0.12 | −0.05 | −0.09 | −0.02 | −0.04 | −0.14 |
| 2024 | −0.06 | −0.21 | −0.15 | −0.08 | −0.05 | −0.06 | −0.17 |

- Up to 2021 the two products agree within about ±0.1 °C a year.
- From 2022 single-sensor runs cooler, by up to 0.2 °C in the Coral Sea and Temperate East, and less in the south.
  The drift starts a year before the 2023 seam, which both products cross on the same date, so the seam isn't the cause.

Night − single-sensor day+night, both re-centred on 2013–2021 (°C):

| year | Coral Sea | North | North-west | South-east | South-west | Temperate East |
|---|---|---|---|---|---|---|
| 2012 | −0.07 | −0.05 | −0.03 | −0.08 | −0.10 | −0.09 |
| 2013 | −0.08 | −0.02 | +0.00 | −0.06 | −0.09 | −0.10 |
| 2014 | −0.09 | −0.14 | −0.07 | −0.07 | −0.10 | −0.08 |
| 2015 | −0.03 | −0.04 | −0.04 | −0.06 | −0.10 | −0.05 |
| 2016 | −0.08 | −0.11 | −0.04 | −0.04 | −0.02 | −0.01 |
| 2017 | −0.09 | −0.07 | −0.02 | +0.01 | +0.01 | −0.01 |
| 2018 | −0.03 | +0.03 | +0.01 | +0.06 | +0.06 | +0.03 |
| 2019 | +0.12 | +0.07 | +0.05 | +0.08 | +0.13 | +0.12 |
| 2020 | +0.14 | +0.15 | +0.05 | +0.04 | +0.06 | +0.06 |
| 2021 | +0.13 | +0.13 | +0.04 | +0.03 | +0.05 | +0.03 |
| 2022 | +0.12 | +0.11 | +0.03 | +0.05 | +0.03 | +0.06 |
| 2023 | +0.05 | +0.03 | +0.06 | +0.09 | +0.08 | +0.07 |
| 2024 | +0.14 | – | +0.03 | +0.08 | +0.06 | +0.10 |

- Night against day+night of the same sensor steps up between 2017 and 2019, in every STAR region, and stays up:
  2019–2024 less 2012–2016 is +0.13 … +0.18 °C (North-west +0.08). Over 1993–2016 the difference is steady
  (year-to-year sd 0.04–0.07 °C, no trend beyond ±0.05 °C/decade).
- Night against multi-sensor doesn't show single-sensor's 2022 drop. It is −0.14 … +0.01 °C in 2012–2016, rises to
  +0.00 … +0.16 in 2019–2021, then comes back to −0.12 … +0.07 in 2022–2024.
- So after 2017 the three products disagree by 0.1–0.2 °C, each in its own way. Against MUR v4.1 and OISST on the
  same cells (`notes/crossover.md`, R/11), the drift is mostly single-sensor day+night. It falls 0.09–0.19 °C
  against MUR (2019–2024 less 2012–2016), multi-sensor falls 0.03–0.11, and night has no lasting step (−0.04 …
  +0.11). So single-sensor trends that run past 2017 are low, and for 1993–2024 the night record is the better
  guide. Night and day+night use the same platforms throughout: NOAA-18 + NOAA-19 until 2018, and NOAA-18 alone
  from 2019-01-01 (`notes/crossover.md`).

## Status: 2024 (q4, anomalies first, °C)

Single-sensor is relative to 1993–2022; multi-sensor to 2013–2022.

| region | 2024 single | warmest year, single | 2024 multi | warmest year, multi |
|---|---|---|---|---|
| Coral Sea | +0.24 (8th of 32) | 2022 (+0.55) | +0.30 (4th of 15) | 2025 (+0.60) |
| North | – (fewer than 10 valid months) | 2016 (+0.97) | +0.03 (7th of 14) | 2016 (+0.63) |
| North-west | +0.30 (7th of 32) | 2016 (+0.57) | +0.14 (4th of 15) | 2016 (+0.35) |
| South-east | +0.16 (12th of 31) | 2017 (+0.44) | +0.02 (10th of 15) | 2017 (+0.26) |
| South-west | +0.14 (11th of 32) | 2011 (+0.69) | +0.21 (5th of 15) | 2013 (+0.56) |
| Temperate East | +0.44 (2nd of 32) | 1998 (+0.50) | +0.50 (1st of 15) | 2024 (+0.50) |
| whole domain | +0.31 (1st of 30) | 2024 (+0.31) | +0.25 (1st of 15) | 2024 (+0.25) |

- 2024 is the warmest year in the whole domain in both products, and the warmest in Temperate East for multi-sensor.
- Night (relative to 1993–2022): 2024 is the warmest of 32 years in Temperate East (+0.57) and in the Continental
  window as a whole (+0.45). Coral Sea is +0.44 (7th; warmest 2022, +0.74), South-east +0.25 (7th of 30),
  South-west +0.22 (6th) and North-west +0.34 (7th). That is 0.04–0.20 °C above day+night, about the size of the step.
- Annual means need at least 10 valid months. Multi-sensor 2025–2026 have fewer files (`notes/issues.md` 10), and
  2026 is part of a year.

## Caveats

- **Ice zone:** AATW and AATE (in `eez`, `eez_legal` and the STAR fill-ins) are marked `ice_zone`. The ice flag is set
  only in some processing eras (`notes/issues.md` 21), so trends there are not to be read until there is a
  time-invariant ice mask. Their single-sensor series don't reach 80% of months anyway. Multi-sensor AATW over
  2013–2024 does, and is flagged.
- **HIMI:** single-sensor has data at HIMI only to about 2012, so there are no HIMI trends. MAC has trends:
  1993–2024 +0.04 [−0.07, +0.15].
- **Cells:**
  - A cell's anomaly covers the whole cell (inside the domain), not just the part in a region. That's fine for EEZ
    territories and STAR regions, but crude for small parks (`amp`): use a finer level for them.
  - Cloud cover still affects which pixels each cell's monthly mean is made from. In the South-east, anomalies on
    L8 cells instead of L5 raise the region trend by up to 0.05 °C/decade (night 1993–2016; see above).
- **Night:**
  - 23 nights have no quality-4 pixel, and most are nearly empty (`notes/issues.md` 22). They failed in the first run
    and were filled by a rerun (`nci/README.md`, step 9). They add to `all` only.
  - The fv02 → fv01 seam was measured for day+night only (`seam_2022` is empty for night), and the night record's
    switch date hasn't been checked.
  - What the range test drops at night is almost all cold: unflagged sub-freezing pixels in the winter ice zone
    (`notes/issues.md` 22). The STAR regions are north of it.
- **Cells left out:** a few cells had too little data for a climatology even before 2013. They are mostly mostly-land
  cells in the north and sparse ones in the far south, and they never contribute.
