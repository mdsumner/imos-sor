# Boundaries and terrestrial sources

Checked 2026-11-17 with GDAL 3.14. "ok" means opened with ogrinfo/gdalinfo or
returned the expected content. Nothing has been downloaded into this repo yet.
A test GPKG of the marine regions is in the session scratchpad only.

Access caveats:
- `services.ga.gov.au/gis/rest/...` returns 403 here. GA's OGC endpoints
  (`/gis/services/.../WFSServer`) and its cloudfront zips work.
- `data.tern.org.au` files need a TERN API key (401).

## Marine: recommended choices

| role | pick | why |
|---|---|---|
| EEZ / TS / CZ (legal) | **GA AMB2020**, Perth-Treaty-amended EEZ | authoritative; includes every external territory **and the AAT** (EEZ-AATW / EEZ-AATE) |
| EEZ for comparing with other nations | VLIZ Marine Regions v12 | globally consistent, but **no AAT** |
| Commonwealth marine parks + zones | **AMP FeatureServer** (216 features) | current: Macquarie expanded 2023-07, HIMI expanded 2025-01, SE rezoning 2025-02 |
| all MPAs incl. state + GBRMP | CAPAD 2024 marine (5,337) via the IMAS WFS | CAPAD 2024 holds the **old** 71k km² HIMI. Use `CAPAD_CURRENT` or AMP for HIMI |
| report regions (STAR 2020) | Commonwealth Marine Regions (6 regions, 17 features) | matches the report. Covers **Commonwealth waters only**: excludes GBRMP, state 3 nm waters, Christmas/Cocos, HIMI |
| bioregions | IMCRA v4.0 provincial (41) | covers the whole EEZ, including Christmas/Cocos/Macquarie |
| Southern Ocean | CCAMLR GIS (MPAs, statistical areas, SSRUs, planning domains); MEASO (measoshapes) | beyond 60°S and around HIMI |

### Endpoints

**GA Australian Maritime Boundaries 2020** (current; previous AMB2014a). CC BY 4.0, GDA94.
- Shapefiles: `https://d28rz98at9flks.cloudfront.net/144571/144571_01_0.zip` (53 MB). GDB is `144571_00_0.zip`.
- `/vsizip//vsicurl/https://d28rz98at9flks.cloudfront.net/144571/144571_01_0.zip/Shapefiles/Exclusive_Economic_Zone_AMB2020_Areas.shp`
  (ok: 9 features, extent 40.85–171.80°E, 69.54–8.47°S). The same zip also has
  `Exclusive_Economic_Zone_Amended_By_Perth_Treaty_1997_AMB2020_Areas`
  (GA's recommended depiction), `Territorial_Sea_*`, `Contiguous_Zone_*`, `Continental_Shelf_AMB2020_Limits` (lines only).
- WFS: `WFS:https://services.ga.gov.au/gis/services/SSLA_1973/MapServer/WFSServer`. The large TS/CZ layers time out over WFS; use the zip.
- 3 nm coastal waters: `https://d28rz98at9flks.cloudfront.net/144567/144567_01_0.zip`.
- Treaties WFS: `WFS:https://services.ga.gov.au/gis/services/Treaties_Australian_Maritime_Boundaries/MapServer/WFSServer`.
- EEZ features are keyed by `National_Object_Name`:
  - EEZ-MLD: mainland, Tasmania, Lord Howe, Ashmore/Cartier
  - EEZ-TST: Torres Strait
  - EEZ-CI: Christmas Island
  - EEZ-CKI: Cocos (Keeling)
  - EEZ-NI: Norfolk
  - EEZ-MAC: Macquarie
  - EEZ-HIMI: Heard and McDonald
  - EEZ-AATW, EEZ-AATE: AAT, either side of Adélie Land
- One Perth Treaty feature misspells HIMI ("Herad and MacDonald").

**VLIZ Marine Regions v12** (DOI 10.14284/632), CC BY 4.0, EPSG:4326.
- `ogr2ogr aus_eez.gpkg WFS:https://geo.vliz.be/geoserver/MarineRegions/wfs MarineRegions:eez -where "sovereign1='Australia'"`
- MRGIDs:
  - Mainland: 8323, 6.87M km²
  - Christmas Island: 8309
  - Cocos: 8308
  - HIMI: 8388, 417k km²
  - Norfolk: 8310
  - Macquarie: 8311, 476k km². Its `iso_ter1` is empty.
  - Torres Strait joint regime: 21798
- Extended continental shelf layer `ecs`: 64204 (mainland), 64116 (HIMI), 64205 (Macquarie).
- The IMAS mirror (`seamap:SeamapAus_BOUNDARIES_Aus_EEZ`) is still v11.

**Australian Marine Parks** (DCCEEW / Parks Australia; HIMI managed by AAD). CC BY 4.0, GDA94.
- `ESRIJSON:https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/Australian_Marine_Parks/FeatureServer/0/query?where=1%3D1&outFields=*&f=json`
  (ok: count 216; HIMI 9 zones, 380,655 km²)
- Fields: NETNAME, RESNAME, ZONENAME, ZONEIUCN, POLYGONID, NATLEGEND, AREA_KM2.
- Outer boundaries only: `.../Australian_Marine_Parks_Outer_Boundary/FeatureServer/0` (61 features).
- Hub shapefile: `https://fed.dcceew.gov.au/api/download/v1/items/2b3eb1d42b8d4319900cf4777f0a83b9/shapefile?layers=0`.
- Networks (features, area):
  - Temperate East: 25, 383k km²
  - South-west: 65, 508k km²
  - South-east: 35, 702k km²
  - North: 21, 157k km²
  - North-west: 27, 335k km²
  - Coral Sea: 28, 990k km²
  - Indian Ocean Territories (2022): 6, 744k km²
  - HIMI: 9, 381k km²
- Zones and IUCN categories:
  - Sanctuary: Ia
  - National Park: II
  - Habitat Protection and Recreational Use: IV
  - Multiple Use and Special Purpose: VI

**CAPAD 2024 marine** (data as at 2024-06-30, released every two years)
- FeatureServer: `https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/CAPAD/FeatureServer/1`. Its maxRecordCount is 3000, so page through the 5,337 features, or use:
- `WFS:https://geoserver.imas.utas.edu.au/geoserver/seamap/wfs`, layers:
  - `seamap:SeamapAus_BOUNDARIES_CAPAD` (2024)
  - `..._CAPAD_CURRENT` (5,350 features, continually updated)
- Hub zip: `https://fed.dcceew.gov.au/api/download/v1/items/0b6e7b6c48a64a3a82c225fa48aee13d/shapefile?layers=1`.

**Commonwealth Marine Regions** (the six regions used in STAR)
- `https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/Commonwealth_Marine_Regions/MapServer/0` (EPSG:3857 native; request `outSR=4326`).
- Filter `ENVIRON='Marine'`, then dissolve by REGION.
- IMAS mirror: `seamap:SeamapAus_BOUNDARIES_Commonwealth_Marine_Regions`.

**IMCRA v4.0**
- Provincial (41 features): `.../ogc_services/IMCRA_Provincial/MapServer/0`.
- Meso-scale (62 features, shelf only): `.../IMCRA_Mesoscale/MapServer/0`.
- The IMAS `SeamapAus_BOUNDARIES_IMCRA_mesoscale_bioregions` layer (92 features) is a different, combined product.
- Key Ecological Features: `.../Key_Ecological_Features/MapServer/0` (polygons) and `/1` (points).

**CCAMLR**
- `WFS:https://gis.ccamlr.org/geoserver/wfs`. Layers:
  - `gis:mpas` (6: South Orkney 2009, Ross Sea 2016 zones)
  - `gis:CCAMLR_MPA_Planning_Domains` (9)
  - `gis:statistical_areas` (19)
  - `gis:ssrus` (63)
  - `gis:polar_fronts`
  - `gis:eez` (4)
- Native CRS ESRI:102020. Every layer has an `_6932` twin in EPSG:6932.

### Consequences for the design

- The STAR regions don't cover the whole EEZ. To get "region totals = EEZ
  total", the region set needs fill-in polygons: GBRMP, state waters,
  Indian Ocean Territories, HIMI, the AAT EEZ. Either build those as the
  EEZ minus the six regions, or use IMCRA provincial, which is complete.
- AMP zones are disjoint within the AMP layer, so they can roll up from zone
  to park to network. CAPAD mixes jurisdictions and can overlap, so it is
  not a partition.
- The legal EEZ (AMB2020) includes the AAT and HIMI. Both lie inside the IMOS
  L3S Southern Ocean domain (2.5–202.5°E, to 77.5°S). That puts the AAT EEZ,
  the expanded HIMI reserve and the Macquarie Island park in the same frame.
- Every vector source above is GDA94 / EPSG:4283 or EPSG:3857. Burn
  in EPSG:4326 longitude/latitude against the 0.02° grids. The GDA94 vs WGS84
  difference (~1 m) is far below the pixel size.

## Terrestrial and coastal cross-over (for later)

| source | access | notes |
|---|---|---|
| DEA (`s3://dea-public-data`, STAC `https://explorer.dea.ga.gov.au/stac`, 101 collections) | anonymous S3/HTTPS, COG, EPSG:3577, CC BY 4.0 | Landsat/S2/S1 ARD; WOfS (`ga_ls_wo_*`, 1986–2025); fractional cover; land cover 1988–2024; geomedians |
| DEA Intertidal v2.1.0 | `derivative/ga_s2ls_intertidal_cyear_3/2-1-0/continental_mosaics/<yr>--P1Y/` (10 m COG, 2016–2024) | marine–land seam; supersedes ITEM/NIDEM |
| DEA Coastlines v3.1.0 | `derivative/dea_coastlines/3-1-0/coastlines_3-1-0.gpkg` (3 GB, /vsicurl ok) | annual shorelines, rates of change |
| DEA mangroves | `ga_ls_mangrove_cover_cyear_3` v4.0.0, 1987–2024 | blue carbon / coastal |
| TERN | STAC `https://stac-api.tern.org.au` (115 collections); files need an API key; anonymous WCS `https://geoserver.tern.org.au/geoserver/ows`, THREDDS `https://dap.tern.org.au/thredds/` | CMRSET AET, SMIPS soil moisture, SLGA soils, phenology, burnt area. `s3://imos-data/TERN/` is only legacy ACEF zips (826 MB) |
| BoM AGCD | `https://thredds.nci.org.au/thredds/catalog/zv2/agcd/v1-0-4/` | 0.05°, precip 1900–2025, tmax/tmin 1910–2025. **CC BY-NC 4.0**. Several versions coexist (v1, v1-0-1..4, v2) |
| ANUClimate 2.0 | `https://thredds.nci.org.au/thredds/catalog/gh70/ANUClimate/v2-0/stable/{day,month}/<var>/` | 0.01°, monthly to 2025-12, CC BY-SA 4.0 |
| AusBathyTopo 250 m **2026** (current) | `/vsizip//vsicurl/https://files.ausseabed.gov.au/survey/AusBathyTopo_Australia_2026_250m.zip/AusBathyTopo_Australia_2026_250m/AusBathyTopo_Australia_2026_250m_MSL_cog.tif` | 92–172°E, 8–60°S. Excludes HIMI/AAT (Kerguelen Plateau 100 m 2022 grid is separate). The superseded 2023 version is a COG on DEA (`projects/ga_ausbathytopo250m_2023/`) |
| AusSeabed survey grids | `s3://ausseabed-public-bathymetry/L3/` (201 surveys); WCS `https://warehouse.ausseabed.gov.au/geoserver/ows` | high-res, patchy |
