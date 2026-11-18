# Crossover: IMOS L3S against MUR and OISST (R/11)

After 2017 the three IMOS L3S products disagree by 0.1–0.2 °C (`notes/trends.md`). This compares each with two
gap-free L4 analyses on the same S2 L5 cells, from trend.sst:

- **MUR:** GHRSST MUR v4.1 (JPL L4, 0.01°, foundation SST, 2002-06 →). These are trend.sst's `ghrsst` sums, made from
  the MUR v4.1 COGs at source.coop/ausantarctic/ghrsst-mur-v2. Known-bad days 2025-08-24..29 are left out.
- **OISST:** NOAA OISST v2.1 (0.25°, 1981-09 →), trend.sst's `oisst` sums.
- **IMOS:** R/09's products, BoM/IMOS ABOM GHRSST L3S 1-day at 0.02° (not MUR): `single` (AVHRR day+night), `multi`
  (day+night) and `single_night` (AVHRR night, skin SST). q4 unless noted.

The script is `R/11_crossover.R` (about 1.5 minutes). Outputs: `trends/crossover_steps.csv` and
`trends/crossover_annual.csv`.

## Method

- **Cells:** the 1,113 S2 L5 cells wholly inside the Continental (aus) window that have ocean. There every IMOS product
  is the Continental file, and the L3S and the L4 cover the same cell. The STAR regions lie wholly in these cells.
- **Matching:** L3S is clear-sky and L4 is gap-free, so a cell-day counts only if the L3S product saw at least half of
  the cell's ocean that day. The difference is the L3S cell mean minus the L4 cell mean. That leaves 14% of
  single-sensor cell-days, 12% of night and 46% of multi-sensor.
- **Anomalies first:** a cell-month is the mean of its matched days (at least 3). Each cell's monthly difference is
  taken less its own calendar-month mean, so months with fewer valid cells don't move the result by which cells they
  are. Regions are R/09's weighted mean of the cells' anomalies. A month needs valid cells over a quarter of the
  region's observable weight (R/09 needs half; single-sensor and night have too few clear cell-days for that). A year
  needs 6 valid months.
- **What it measures:** anything steady (skin vs foundation, the coastal footprint, clear-sky bias at a given
  coverage) is an offset and cancels. A drift is a change in the difference.
- **Reference check:** MUR − OISST on every day of the same cells.

## Steps after 2017

The step is 2019–2024 less 2012–2016, in the anomaly of the difference (°C; the night step in `notes/trends.md` uses
the same years):

| region | single − MUR | single − OISST | multi − MUR | multi − OISST | night − MUR | night − OISST | MUR − OISST |
|---|---|---|---|---|---|---|---|
| aus window | −0.15 | −0.14 | −0.05 | −0.08 | +0.01 | +0.02 | 0.00 |
| Coral Sea | −0.19 | −0.15 | −0.05 | −0.06 | −0.04 | +0.01 | +0.01 |
| North | −0.04 | −0.21 | −0.03 | −0.17 | +0.11 | −0.03 | −0.10 |
| North-west | −0.09 | −0.15 | −0.09 | −0.17 | 0.00 | −0.06 | −0.05 |
| South-east | −0.14 | −0.18 | −0.10 | −0.16 | +0.02 | −0.03 | −0.06 |
| South-west | −0.13 | −0.10 | −0.11 | −0.09 | +0.01 | +0.05 | +0.02 |
| Temperate East | −0.16 | −0.17 | −0.10 | −0.13 | 0.00 | −0.01 | −0.03 |

Year-to-year sd over 2012–2016: single − MUR 0.02–0.10, multi − MUR 0.02–0.06, night − MUR 0.02–0.09,
MUR − OISST 0.05–0.15.

- **Single-sensor day+night drifts down.** It falls 0.09–0.19 °C against MUR (aus window −0.15) and 0.10–0.21 against
  OISST, in every region except North against MUR. In the aus window it is steady to 2017 and falls from 2018 to
  2022: −0.03, −0.06, −0.06, −0.11, −0.18, −0.14, −0.17 °C (2018–2024, against MUR).
- **Night has no lasting step.** Against MUR it is +0.01 (aus window) and −0.04 … +0.02 in five of the six regions.
  North is +0.11. Against OISST it is −0.06 … +0.05. It does wander: in the aus window it is −0.07 in 2012–2013,
  +0.04 … +0.08 in 2017–2020, and −0.03 … −0.08 in 2021–2024.
- **Multi-sensor drifts down a little:** −0.03 … −0.11 against MUR (aus window −0.05), more against OISST. Against
  MUR it falls about 0.1 from 2016 to 2022, then rises 0.06 in 2023.
- **So the night-against-day+night step of +0.13 … +0.18 is mostly single-sensor falling, not night rising.**
  Single-sensor trends that run past 2017 are low: South-east 2013–2024 is −0.15 single, −0.11 multi, 0.00 night
  (°C/decade). For 1993–2024 the night record (South-east +0.20) is the better guide than single-sensor (+0.16).
- **The references:** MUR and OISST agree on the aus window (step 0.00), but differ by up to 0.10 in a region (North).
  A step against OISST is about the step against MUR plus MUR − OISST, so the two references tell the same story
  wherever they agree.

## Before 2017

The drift is OLS on the monthly anomaly of the difference, with R/09's AR(1)-inflated 95% interval (°C/decade):

- **Against MUR, 2003–2016:** single and night are steady. Single is +0.01 … +0.07 (aus window +0.01
  [−0.03, +0.05]), and night −0.04 … +0.06 (aus window −0.03 [−0.07, +0.02]). Every interval includes zero; two
  only just reach it: South-west single +0.04 [+0.00, +0.08] and South-east night −0.04 [−0.09, +0.00].
- **The references disagree in two regions over 2003–2016:** MUR − OISST is −0.12 [−0.19, −0.06] in the South-east and
  −0.12 [−0.21, −0.02] in the North-west, so OISST warms faster there than MUR.
- **Against OISST, 1993–2016:**
  - Single and night drift the same way, region by region: South-east −0.14 [−0.20, −0.09] and
    −0.15 [−0.21, −0.09], North +0.13 and +0.15, South-west −0.08 and −0.10. Aus window −0.04 [−0.08, +0.00] and
    −0.01 [−0.06, +0.05].
  - Two AVHRR records with different processing agree, and in the South-east MUR also warms less than OISST. So OISST
    is the likely outlier there, not the L3S.
  - This doesn't bring STAR 1.2's "~1 °C per decade" any closer. OISST's South-east trend would be about +0.15 above
    the night record's +0.23.

## Checks

- **Clear-sky cut:** at clear ≥ 0.8 instead of 0.5 the aus window steps are single − MUR −0.13, multi − MUR −0.06 and
  night − MUR +0.01; against OISST −0.17, −0.09 and −0.04.
- **q4b** (q4 less `sses_bias`): single − MUR −0.12, multi − MUR −0.04, night − MUR +0.02.
- **Offsets** (the steady part, L3S − L4):
  - night − MUR −0.20 … −0.33 °C (aus window −0.27), as expected for night skin against foundation SST
  - single − MUR −0.17 … +0.01
  - multi − MUR −0.10 … +0.03
  - MUR − OISST 0.00 … +0.24
- **The fv02 → fv01 seam (2023-01-01):** 2023 less 2022, aus window: +0.06 (multi), +0.04 (single) and +0.03
  (night) against MUR, but +0.03, −0.03 and −0.04 against OISST. MUR − OISST itself moves −0.04 between those years,
  so no seam can be read here.

## Caveats

- MUR and OISST aren't independent of the L3S: OISST is AVHRR-based, and MUR uses AVHRR among its inputs. Where all three IMOS
  products and both references move together, this can't tell.
- What changes the single-sensor record after 2017 isn't known. The night record shares its sensors but not its
  daytime retrievals. The candidates are daytime retrievals, which platforms make up the record, and the platforms'
  overpass times. The night files' platform attributes across 2017–2019 are still to be checked.
- Matching on clear cell-days leaves single-sensor and night with few cells in some months. A year can rest on 3–5
  valid months before about 1995, and night in the Coral Sea on 7–8 in some years (2019, 2024).
