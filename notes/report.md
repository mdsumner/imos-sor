# STAR 2020: inventory and refresh map

*State and Trends of Australia's Ocean Report* (2019 report, published March
2020). Richardson A.J., Eriksen R., Moltmann T., Hodgson-Johnston I., Wallis J.R.
(Eds). IMOS. Site: <https://www.imosoceanreport.org.au/>. Full PDF (164 pp):
`~/STAR-Report-March-2020.pdf`, also
<https://www.imosoceanreport.org.au/wp-content/uploads/2020/04/STAR-Report-March-2020.pdf>.
Per-section PDFs and figures live under `wp-content/uploads/2020/0[1-3]/STAR<n.n>-<Author>.et.al.*`.

Regions: six marine bioregional plan regions (EPBC Act; GBR shown separately
and not among the six), "continental EEZ" (200 nm), east/west boxes, the seven NRS
(DAR, YON, NSI, ROT, PHB, KAI, MAI). No marine parks.

**Refresh** column: where the input lives now. `Z:` = Zarr store in
`s3://aodn-cloud-optimised`, `P:` = Parquet there, `BGC:` = CSV in
`s3://imos-data/IMOS/BGC_DB/harvested_from_CSIRO/`, `NC:` = NetCDF prefix in
`s3://imos-data/`, `ext` = outside IMOS.

## 1. Physical and chemical environment

| # | series | period | headline (as published) | original sources | refresh |
|---|---|---|---|---|---|
| 1.1 | Long-term temperature | 1870–2018 | °C/century by region: SE 1.1, SW 0.99, TE 0.93, Coral Sea 0.8, N 0.74, NW 0.6 | HadISST1; NRS long-term product (1944–2014) | ext HadISST; NC `UNSW/NRS_climatology/`; Z L3S single-sensor 1992→ for the satellite era |
| 1.2 | SST variability | 1993–2016 | ~1 °C/decade in SE; none on west coast | IMOS L3S 1-day night; SSTAARS | Z `satellite_ghrsst_l3s_1day_nighttime_single_sensor_australia`; NC `CSIRO/Climatology/SSTAARS/` |
| 1.3 | EAC variability | 2015–2018 (mooring), 2010→ (radar) | EAC transport 22.1 ± 7.5 Sv at 27°S | EAC mooring array; GSLA; Coffs Harbour HF radar | NC `IMOS/DWM/DA/EAC*`; Z `model_sea_level_anomaly_gridded_delayed`; Z `radar_CoffsHarbour_*` |
| 1.4 | Current variability (KE/EKE) | 1993–2019-04 | Leeuwin more variable than EAC | GSLA DM | Z `model_sea_level_anomaly_gridded_delayed` (has UCUR/VCUR) |
| 1.5 | Nutrients | 2010–2018 (+70-yr at PHB/ROT/MAI) | no trends at the 7 NRS; silicate at MAI >3 → 1 µM since 1970 | NRS | BGC `bgc_chemistry.csv` |
| 1.6 | Acidification | 1870–1890 vs 2000–2009; moorings 2012–2016 | pH down ≤0.11; Ωarag down ≤0.6 | Lenton climatology; NRS carbon; KAI/MAI CO2 moorings | NC `CSIRO/Climatology/Ocean_Acidification/`; P `mooring_acidification_*`, `vessel_co2_*`; BGC chemistry |

## 2. Biological productivity

| # | series | period | headline | original sources | refresh |
|---|---|---|---|---|---|
| 2.1 | Chlorophyll a | 2003–2019 | region/EEZ ~−8 % (−0.5 %/yr); EEZ mean 0.26 mg m⁻³ | NASA MODIS Aqua, OCI | Z `satellite_chlorophylla_oci_1day_aqua` (→2024-12) + `_snpp`/`_noaa20` (seam) |
| 2.2 | Net primary production | 2002-12–2019-01 | EEZ −0.6 %/yr (~10 %); region −12 % | Oregon State carbon-based model | Z `satellite_net_primary_productivity_{gsm,oc3}_1day_aqua` (IMOS's own NPP; different model) |
| 2.3 | Plankton communities | 2009–2019 | KAI phyto biovolume −96 %/decade; Darwin zoop biomass +174 mg m⁻³/decade | NRS | BGC `bgc_phyto_raw`, `bgc_zoop_raw`; planktonr |
| 2.4 | Phytoplankton seasons (phenology) | 2003–2018 climatology | 6 k-means phenology regions | MODIS Aqua OCI | Z chl stores |
| 2.5 | Depth layers (MLD, Zeu, DCM) | 2008–2018 | DCM deepening NSI 0.9, MAI 1.02 m/yr | NRS CTD | P `vessel_ctd_profiles_delayed_qc`; NC `IMOS/ANMN/NRS/` |
| 2.6 | Picophytoplankton | 2009–2018 | tropical pico increasing in Tasmania | NRS flow cytometry | BGC `bgc_picoplankton*`; Z `satellite_picoplankton_fraction_oc3_1day_aqua` |
| 2.7 | Microbial assemblages | 2012→ | — | Australian Microbiome | ext (AMI; planktonr reads the AusMicrobiome atlas CSV) |

## 3. Water quality

| # | series | period | headline | original sources | refresh |
|---|---|---|---|---|---|
| 3.1 | Water clarity | 2002–2019 | Secchi 24 m in EEZ; no trend | MODIS Secchi (Morel); NRS TSS/Secchi | Z `satellite_diffuse_attenuation_coefficent_1day_*` (Kd490 proxy); BGC `bgc_tss*` |
| 3.2 | Trichodesmium | 2009→ | up at Yongala, down at NSI | NRS, AusCPR, APD; L3S SST; MODIS chl | BGC `bgc_phyto_raw`, `cpr_phyto_raw` |
| 3.3 | Tripos indicators | 1940–2019 | 8 rare tropical spp. flagged | NRS, AusCPR, SO-CPR, APD | BGC phyto, CPR |
| 3.4 | HABs and shellfish | 2003–2019 | trigger-level exceedance N NSW 2.0 % … PPB 0.2 % | state shellfish programs (APD) | ext + AODN uuid 75f4f1fc-bee3-4498-ab71-aa1ab29ab2c0 |
| 3.5 | HABs in NSW | 1998–2018 | case studies | NSW Food Authority / DPI | ext |
| 3.6 | Noctiluca range | 1860–2018 | Tasmania 1994, SO 2010, Darwin 2014, Rottnest 2017 | APD, AusCPR, SO-CPR, NRS | BGC CPR/NRS; SO-CPR (AADC) |

## 4. Marine animals

| # | series | period | headline | original sources | refresh |
|---|---|---|---|---|---|
| 4.1 | Copepods vs east coast warming (CTI) | 1928/1931/1971 → 2019 | CTI +1.5 °C PHB, +1.6 °C MAI, ~+1 °C YON | NRS, AusCPR, SO-CPR, Australian Zooplankton DB | BGC `bgc_zoop_raw`, `cpr_zoop_raw` |
| 4.2 | Zooplankton and the 2011 WA heatwave | 2009→ | biomass, abundance and size dropped | NRS ROT | BGC zoop; Z `satellite_austemp_heatwave_14day` (from 2012) |
| 4.3 | Zooplankton as EAC index | 2010–2018 | index vs SSTA R = 0.60 | AusCPR; RAMSSA | BGC `cpr_zoop_raw`; Z `satellite_ghrsst_l4_ramssa_1day_*` |
| 4.4 | Calcifying zooplankton | ~2009–2019 | no overall decline | NRS zoop + carbon | BGC |
| 4.5 | Twilight zone (38 kHz) | 2004–2018 | winter backscatter +42 to +105 % Tasman; SO +77 % | BASOOP | NC `IMOS/SOOP/SOOP-BA/` |
| 4.6 | Larval fish | 1983→ | latitudinal gradient weakened after 1998 | surveys + NRS | BGC `bgc_lfish_*`; NC `CSIRO/Atlas/Larval_Fish/` |
| 4.7 | Bull shark migrations | 2007–2017 | 60–1770 km one-way | Animal Tracking acoustic | P `animal_acoustic_tracking_delayed_*` |
| 4.8 | Elephant seals, Macquarie Is. | 60+ yr | −1.2 %/yr | counts (ext); CTD tags | P `animal_ctd_satellite_relay_tagging_*`; counts ext (AAD) |

## Observations for the follow-on

- About half the series (most of 1.5, 2.3, 2.5–2.7, 3.2–3.6, 4.1–4.6) are
  station or route biology. They are cheap to refresh from BGC_DB, but they
  cannot be regionalised beyond their stations and routes.
- The gridded half (1.1–1.4, 2.1, 2.2, 2.4, 3.1) maps one-to-one onto IMOS
  Zarr stores at 0.01–0.02°, which is fine enough for parks.
- Reported numbers that don't agree in the original: chl "~8 %" against "over 17
  years"; NPP 12 % (region) against ~10 % (EEZ) against "9 % overall" in the PDF
  table text. Worth reproducing exactly before extending.
