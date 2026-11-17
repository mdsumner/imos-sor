# One TSV row of selected netCDF global attributes from `ncdump -h` output.
#   ncdump -h f.nc | awk -v p=f.nc -f nc_globals.awk
# Columns: p, then the attributes in K (NA if absent), then
# sea_surface_temperature:add_offset (computed per file from the data, so a
# content fingerprint that survives IMOS's attribute edits).
# Values: surrounding quotes and the trailing " ;" dropped, tabs -> spaces.
BEGIN {
  n = split("uuid id product_version date_created netcdf_version_id Conventions start_time stop_time file_quality_level source", K, " ")
}
/^\t\tsea_surface_temperature:add_offset = / {
  off = substr($0, index($0, " = ") + 3); sub(/ ;$/, "", off); sub(/[fd]$/, "", off)
}
/^\/\/ global attributes:/ { g = 1; next }
g && /^\t\t:/ {
  k = substr($0, 4, index($0, " = ") - 4)
  v = substr($0, index($0, " = ") + 3); sub(/ ;$/, "", v); sub(/^"/, "", v); sub(/"$/, "", v); gsub(/\t/, " ", v)
  a[k] = v
}
END {
  printf "%s", p
  for (i = 1; i <= n; i++) printf "\t%s", ((K[i] in a) ? a[K[i]] : "NA")
  printf "\t%s\n", (off == "" ? "NA" : off)
}
