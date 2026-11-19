# S2 L5 cells for IMOS's MEOP-QC'd seal and turtle CTD profiles, from the
# index that py/meop_refs.py reads out of the netCDF-3 files on S3.
#
# Positions: every species here lives in the southern hemisphere, so a profile
# north of the equator has a bad position (19,484 of them, in the Weddell seal
# campaigns ct150 and ct156 and the fur seal campaigns ct91, ct101 and ct110;
# notes/issues.md 23). They are kept and flagged (pos_ok = FALSE), not moved.
# The files' own geospatial_* bounds can't be used as a screen: they are wrong
# across the antimeridian and for some campaigns.
# Cells: S2 L5 cell of the profile position (s2, as R/06), tokens matched to
# trend.sst's registry. Species labels are merged ("Southern ellie" and
# "Southern elephant seal"; "Weddel seal").
#
# Writes data/animal/meop_profiles.parquet (one row per profile) and, committed,
# inventory/meop_cells.csv (profiles per cell) and inventory/meop_files.csv
# (one row per file: tag, species, release, shape, time span, bad positions).
# usage (from the repo root): Rscript R/14_meop_cells.R
suppressPackageStartupMessages(library(data.table))
p <- as.data.table(nanoparquet::read_parquet("data/animal/meop_profiles_raw.parquet"))
p[, time := as.POSIXct("1950-01-01", tz = "UTC") + juld * 86400]
p[, pos_ok := is.finite(lat) & lat < 0 & lat >= -90 & abs(lon) <= 360]
p[, species := fcase(species_label %in% c("Southern ellie", "Southern elephant seal"), "southern elephant seal",
                     species_label %in% c("Weddell seal", "Weddel seal"), "Weddell seal", species_label == "Fur seal", "fur seal",
                     default = tolower(species_label))]
reg <- as.data.table(nanoparquet::read_parquet(path.expand("~/Git/trend.sst/s2_registry.parquet")))
p[pos_ok == TRUE, cell := as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_geog_point(ifelse(lon > 180, lon - 360, lon), lat)), 5L))]
stopifnot(all(p[pos_ok == TRUE, cell] %in% reg$cell))
map <- readRDS("data/mapping/union_s2l5.rds"); lattice_cells <- unique(reg$cell[as.vector(map$idx)])
p[, in_l3s := cell %chin% lattice_cells]
nanoparquet::write_parquet(as.data.frame(p[, .(key, smru, wmo, species, species_label, location, deployment, release, n_levels, row, cycle,
                                               time, lat, lon, position_qc, pos_ok, cell, in_l3s)]), "data/animal/meop_profiles.parquet")

cells <- p[pos_ok == TRUE, .(profiles = .N, tags = uniqueN(key), days = uniqueN(as.Date(time)), first = as.Date(min(time)), last = as.Date(max(time)),
                             species = paste(sort(unique(species)), collapse = "; ")), by = cell]
cells <- merge(cells, reg[, .(cell, lon = round(lon, 2), lat = round(lat, 2))], by = "cell")[, in_l3s := cell %chin% lattice_cells][order(-profiles)]
fwrite(cells, "inventory/meop_cells.csv")
files <- p[, .(smru = smru[1], wmo = wmo[1], species = species[1], deployment = deployment[1], location = location[1], release = release[1],
               n_levels = n_levels[1], profiles = .N, bad_positions = sum(!pos_ok), first = as.Date(min(time)), last = as.Date(max(time))), by = key]
fwrite(files, "inventory/meop_files.csv")

cat(sprintf("%d profiles in %d files; positions ok %d (bad %d); %s .. %s\n", nrow(p), nrow(files), sum(p$pos_ok), sum(!p$pos_ok),
            format(min(p$time)), format(max(p$time))))
print(files[, .(files = .N, profiles = sum(profiles), n_levels = paste(sort(unique(n_levels)), collapse = " "), first = min(first), last = max(last)), by = release])
cat(sprintf("cells with profiles: %d of %d (%d in the IMOS L3S lattice, holding %.1f%% of the profiles); south of 50 S %d, south of 60 S %d\n",
            nrow(cells), nrow(reg), sum(cells$in_l3s), 100 * sum(cells[in_l3s == TRUE, profiles]) / sum(cells$profiles), sum(cells$lat < -50), sum(cells$lat < -60)))
cat(sprintf("median %d profiles a cell; %d cells with >= 100, %d with >= 1000\n", as.integer(median(cells$profiles)), sum(cells$profiles >= 100), sum(cells$profiles >= 1000)))
print(p[, .(profiles = .N, ok = sum(pos_ok), cells = uniqueN(cell, na.rm = TRUE)), by = species][order(-profiles)])
print(head(cells, 10))
