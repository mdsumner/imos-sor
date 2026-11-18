# Trends and status from the in-situ L3S sums (R/09)

These are BoM/IMOS ABOM GHRSST L3S 1-day **day+night** composites at 0.02°, not MUR.
- **single-sensor:** AVHRR, 1992-03 → 2025-06.
- **multi-sensor:** 2012-01 → 2026-11.

The input is the daily sums from `nci/sums.R`. Ice-flagged pixels and SST outside −2.5 … 40 °C have already been dropped (`nci/README.md`, step 9).
The script is `R/09_trends.R`, which runs in about 2 minutes. Its committed outputs are `trends/region_trends.csv`,
`trends/cell_trends_q4.csv`, `trends/region_status.csv` and `trends/region_monthly_q4.csv.gz`.

## Method

- **Monthly sums:** daily sums add up to monthly sums for each S2 L5 cell and each region.
- **Climatology:** calendar-month means over each product's base years. Single-sensor uses 1993–2022, needing at least
  15 of the 30 years. Multi-sensor uses 2013–2022, needing at least 7 of 10.
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

- **West coast:** South-west is +0.11 [−0.15, +0.38], so a trend can't be told from zero. That agrees with STAR.
- **South-east:** the region as a whole is +0.21 [+0.06, +0.37]. The fastest S2 L5 cells mostly inside it are
  +0.43 to +0.49 °C/decade, east of Tasmania and in the southern Tasman (151.8°E 42.6°S +0.49; 149.8°E 39.7°S +0.47;
  152.8°E 40.5°S +0.45).
- **So ~1 °C/decade isn't reached at L5.** L5 cells are about 290 km across, so a narrower hotspot would be smoothed
  out. These sums are also day+night, where STAR used night only.
- Next: run the night-only product (`L3S-1d/ngt`, Continental only, on sh74), and look at a finer S2 level around
  south-east Australia.

## Single- vs multi-sensor

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
- An independent reference is needed to say which product drifts: the MUR v4.1 and OISST sums in trend.sst, on the
  same S2 L5 cells.

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
  - Cloud cover still affects which pixels each cell's monthly mean is made from.
- **Cells left out:** a few cells had too little data for a climatology even before 2013. They are mostly mostly-land
  cells in the north and sparse ones in the far south, and they never contribute.
