# BoM qm43 GHRSST (ABOM L3S/L3C, not MUR): where file versions fv01 and fv02
# start, stop and overlap, from the qm43 inventory made on Gadi.
#
# Writes data/nci/counts-qm43_ghrsst.tsv (directory, year, files, bytes: what
# inventory.pbs would have written) and nci/qm43_l3s_seams.csv (committed):
# one row per domain x sensor x version for the 1-day L3S day+night files,
# with first/last date, days present, days missing within that span, and the
# days held by both versions. Also prints the per-year table.
#
# usage (from the repo root): Rscript nci/qm43_seams.R [data/nci/inventory-qm43_ghrsst.tsv.gz]
args <- commandArgs(TRUE)
f <- if (length(args)) args[1] else "data/nci/inventory-qm43_ghrsst.tsv.gz"
inv <- read.delim(gzfile(f), header = FALSE, col.names = c("path", "size", "mtime"),
                  colClasses = c("character", "numeric", "numeric"), quote = "")
inv <- inv[grepl("\\.nc$", inv$path), ]

## directory-year counts
yr <- basename(dirname(inv$path))
ok <- grepl("^[0-9]{4}$", yr)
key <- paste(dirname(dirname(inv$path[ok])), yr[ok], sep = "\t")
cnt <- data.frame(key = names(table(key)), files = as.integer(table(key)),
                  bytes = as.numeric(tapply(inv$size[ok], key, sum)))
writeLines(paste(cnt$key, cnt$files, sprintf("%.0f", cnt$bytes), sep = "\t"), "data/nci/counts-qm43_ghrsst.tsv")

## 1-day L3S day+night files, both versions
b <- basename(inv$path)
l3s <- grepl("-ABOM-L3S_GHRSST-SSTfnd-.*-1d_dn(_Southern)?-v02\\.0-fv0[12]\\.0\\.nc$", b) & grepl("/dn/", inv$path)
x <- data.frame(path = inv$path[l3s], file = b[l3s], size = inv$size[l3s])
x$date <- as.Date(substr(x$file, 1, 8), "%Y%m%d")
x$version <- sub(".*-(fv0[12])\\.0\\.nc$", "\\1", x$file)
x$domain <- ifelse(grepl("_Southern-", x$file), "Southern", "Continental")
x$sensor <- sub("^.*-SSTfnd-(.*)-1d_dn.*$", "\\1", x$file)
x$tmp <- grepl("\\.tmp$", x$path)
dup <- duplicated(x[c("date", "version", "domain", "sensor")])
if (any(dup)) message(sum(dup), " duplicate (date, version, domain, sensor) entries, e.g. ", x$path[dup][1])
x <- x[!dup, ]

grp <- split(x, list(x$domain, x$sensor, x$version), drop = TRUE)
seams <- do.call(rbind, lapply(grp, function(g) {
  other <- x[x$domain == g$domain[1] & x$sensor == g$sensor[1] & x$version != g$version[1], ]
  span <- as.numeric(max(g$date) - min(g$date)) + 1
  data.frame(domain = g$domain[1], sensor = g$sensor[1], version = g$version[1],
             first = min(g$date), last = max(g$date), days = nrow(g), missing_in_span = span - nrow(g),
             also_in_other_version = sum(g$date %in% other$date),
             dirs = paste(unique(sub("/[0-9]{4}/[^/]*$", "", g$path)), collapse = " "))
}))
seams <- seams[order(seams$domain, seams$sensor, seams$version), ]
write.csv(seams, "nci/qm43_l3s_seams.csv", row.names = FALSE)
print(seams[, setdiff(names(seams), "dirs")], row.names = FALSE)
cat("\n"); print(unique(seams$dirs))

## per year: days present by version, and the union
x$year <- format(x$date, "%Y")
tab <- with(x, table(paste(domain, sensor), year, version))
for (v in dimnames(tab)$version) { cat("\n==", v, "\n"); print(tab[, , v]) }
u <- with(unique(x[c("domain", "sensor", "date", "year")]), table(paste(domain, sensor), year))
cat("\n== union of fv01 and fv02 (distinct days)\n"); print(u)
