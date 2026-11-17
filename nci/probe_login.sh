#!/bin/bash
## Quick look at the NCI holdings relevant to imos-sor, from a Gadi login node.
## Light on the filesystem: ls only, no deep find. Writes a report to
## $OUT (default ~/imos-sor-probe/login-<date>.txt) and prints it.
##
##   bash probe_login.sh
##
## What it answers: which projects you can read; how the IMOS/AODN mirror
## (sh74) is laid out and whether it holds the cloud-optimised Zarr/Parquet
## as well as the NetCDF archive; per-year file counts for the L3S products
## used so far (to compare with s3://imos-data and qm43 THREDDS).
set -u
OUT=${OUT:-$HOME/imos-sor-probe/login-$(date +%Y%m%d-%H%M).txt}
mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

echo "# imos-sor NCI probe, $(date -Is), $(hostname), user $USER"
echo "## groups"; id -Gn | tr ' ' '\n' | sort | tr '\n' ' '; echo

echo "## project readability (/g/data/<p>)"
## sh74 IMOS/AODN mirror; qm43 BoM satellite SST; gb6 BRAN; jk72 compute home;
## rr1 GA elevation/bathymetry; zv2 AGCD; gh70 ANUClimate; xu18/ka08/jw04 GA
## Landsat/S2 ARD and derivatives (DEA on NCI); ob53 BARRA2; fx3 eReefs; ra22/rv74 BoM satellite
for p in sh74 qm43 gb6 jk72 rr1 zv2 gh70 xu18 ka08 jw04 ob53 fx3 ra22 rv74 xp65; do
  if [ -d /g/data/$p ]; then
    if ls /g/data/$p >/dev/null 2>&1; then s=readable; else s="exists, not readable"; fi
  else s=absent; fi
  printf '  %-5s %s\n' "$p" "$s"
done

M=/g/data/sh74/IMOS_AODN
echo "## $M"
if ls "$M" >/dev/null 2>&1; then
  ls -la "$M"
  echo "### two levels"
  for d in "$M"/*/; do echo "$(basename "$d")/: $(ls "$d" 2>/dev/null | tr '\n' ' ')"; done
  echo "### IMOS/ facilities"
  ls "$M/IMOS" 2>/dev/null | tr '\n' ' '; echo
  echo "### cloud-optimised? (any *.zarr / *.parquet within 3 levels)"
  find "$M" -maxdepth 3 \( -name '*.zarr' -o -name '*.parquet' \) -print 2>/dev/null | head -20
  echo "### README / manifest files at the top"
  ls "$M" | grep -i -E 'readme|manifest|licen|sync|log' || echo "  (none)"
  echo "### IMOS_AODN_README.txt"
  sed 's/^/  | /' "$M/IMOS_AODN_README.txt" 2>/dev/null | head -150
  echo "### IMOS/CO (cloud-optimised?) and wave_buoy_data, two levels"
  for d in "$M/IMOS/CO" "$M/wave_buoy_data/IMOS"; do echo "$d:"; ls "$d" 2>/dev/null | head -40 | sed 's/^/  /'; done
  G=$M/IMOS/SRS/SST/ghrsst
  echo "### $G"
  ls "$G" 2>/dev/null | tr '\n' ' '; echo
  echo "### per-year .nc counts (compare with s3://imos-data, see imos-sor/nci/README.md)"
  for p in L3S-1d/dn L3S-1dS/dn L3SM-1d/dn L3SM-1dS/dn; do
    printf '  %-12s' "$p"
    for y in 2010 2015 2020 2022 2023 2024 2025 2026; do
      n=$(ls "$G/$p/$y" 2>/dev/null | grep -c '\.nc$'); printf ' %s:%s' "$y" "$n"
    done; echo
  done
  echo "### newest files (mirror freshness)"
  for p in L3SM-1d/dn L3SM-1dS/dn; do
    y=$(ls "$G/$p" 2>/dev/null | sort | tail -1)
    echo "  $p: $(ls -l --time-style=+%Y-%m-%dT%H:%M "$G/$p/$y" 2>/dev/null | tail -1 | awk '{print $6, $7}')"
  done
else
  echo "  not readable: join sh74 at https://my.nci.org.au (Projects > Find project > sh74)"
fi

Q=/g/data/qm43/ghrsst
echo "## $Q"
if ls "$Q" >/dev/null 2>&1; then
  ls "$Q" | tr '\n' ' '; echo
  ls "$Q/v02.0fv02" 2>/dev/null | tr '\n' ' '; echo
else
  echo "  not readable (THREDDS works without membership; in-situ needs qm43)"
fi
echo "# report: $OUT"
