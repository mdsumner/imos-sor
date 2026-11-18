# Check the screened in-situ sums (sums-v2) against the first run (sums, no
# screen), product-month by product-month:
#  - the same days, files and finite pixel counts per window (n_aus, n_so)
#  - domain "all" count: v1 - v2 == ice + range dropped, exactly, every day
#  - q4/q4b domain counts and every region and S2 cell count: v2 <= v1
#  - S2 cells the screen didn't touch (same n): identical sums
#  - the range of S2 cell means in v2 (q4b can go below the screen: sses_bias
#    is subtracted after it)
# usage (from the repo root): Rscript nci/sums_check.R [v1 = data/nci/sums] [v2 = data/nci/sums-v2]
# Writes nci/sums_check.csv: one row per product-month, the checks, and the
# finite, ice and out-of-range pixel totals.
a <- commandArgs(TRUE)
v1 <- if (length(a) >= 1) a[1] else "data/nci/sums"
v2 <- if (length(a) >= 2) a[2] else "data/nci/sums-v2"
scr <- readRDS(file.path(v2, "screen.rds"))
f2 <- Sys.glob(file.path(v2, "*", "*.rds"))
cat("v2 product-months:", length(f2), "\n")
k4 <- c("date", "variant", "set", "region_id")
res <- do.call(rbind, lapply(f2, function(f) {
  b <- readRDS(f); g <- file.path(v1, b$product, paste0(b$month, ".rds"))
  if (!file.exists(g)) return(data.frame(product = b$product, month = b$month, note = "no v1"))
  a <- readRDS(g)
  d <- merge(a$days, b$days, by = "date", suffixes = c(".1", ".2"))
  same_days <- nrow(d) == nrow(a$days) && nrow(d) == nrow(b$days)
  same_files <- all(d$file_aus.1 == d$file_aus.2 & d$file_so.1 == d$file_so.2)
  ok2 <- d$error.2 == "" & d$error.1 == ""
  same_n <- all(d$n_aus.1[ok2] == d$n_aus.2[ok2] & d$n_so.1[ok2] == d$n_so.2[ok2])
  dom <- merge(a$regions[a$regions$set == "domain", ], b$regions[b$regions$set == "domain", ], by = k4, suffixes = c(".1", ".2"))
  da <- merge(dom[dom$variant == "all", c("date", "n.1", "n.2")], b$days, by = "date")
  drop_exact <- all(da$n.1 - da$n.2 == da$ice_aus + da$ice_so + da$range_aus + da$range_so)
  reg <- merge(a$regions, b$regions, by = k4, suffixes = c(".1", ".2"))
  reg_le <- all(reg$n.2 <= reg$n.1 + 1e-9)
  s <- merge(a$s2, b$s2, by = c("date", "variant", "cell"), all.x = TRUE, suffixes = c(".1", ".2"))
  new_cells <- nrow(b$s2) - sum(!is.na(s$n.2))
  s2_le <- all(is.na(s$n.2) | s$n.2 <= s$n.1)
  u <- s[!is.na(s$n.2) & s$n.2 == s$n.1, ]
  untouched_same <- all(u$sumw.1 == u$sumw.2 & u$sumwx.1 == u$sumwx.2 & u$sumwx2.1 == u$sumwx2.2)
  m <- b$s2$sumwx / b$s2$sumw
  data.frame(product = b$product, month = b$month, days = nrow(b$days), failed = sum(b$days$error != ""),
             same_days, same_files, same_n, drop_exact, reg_le, s2_le, new_cells, untouched_same,
             cell_mean_min = min(m), cell_mean_max = max(m),
             fin = sum(b$days$n_aus + b$days$n_so, na.rm = TRUE),
             ice = sum(b$days$ice_aus + b$days$ice_so, na.rm = TRUE),
             range = sum(b$days$range_aus + b$days$range_so, na.rm = TRUE), note = "")
}))
chk <- c("same_days", "same_files", "same_n", "drop_exact", "reg_le", "s2_le", "untouched_same")
cat("all checks pass in", sum(apply(res[chk], 1, all) & res$new_cells == 0, na.rm = TRUE), "of", nrow(res), "product-months\n")
bad <- res[!(apply(res[chk], 1, all) & res$new_cells == 0) | res$note != "", ]
if (nrow(bad)) print(bad[c("product", "month", "note", chk, "new_cells")], row.names = FALSE)
cat("failed days:", sum(res$failed), "\n")
cat("S2 cell means in v2:", range(c(res$cell_mean_min, res$cell_mean_max)), " (screen", scr$sst_min, "..", scr$sst_max, ")\n")
res$year <- substr(res$month, 1, 4)
y <- aggregate(cbind(fin, ice, range) ~ product + year, res, sum)
y$ice_pct <- round(100 * y$ice / y$fin, 3); y$range_pct <- round(100 * y$range / y$fin, 3)
cat("\nscreened share of finite pixels, by product and year:\n")
print(reshape(y[c("product", "year", "ice_pct", "range_pct")], idvar = "year", timevar = "product", direction = "wide"), row.names = FALSE)
write.csv(res[setdiff(names(res), c("note", "year"))], "nci/sums_check.csv", row.names = FALSE)
