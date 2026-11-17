# Summarise the fv01 vs fv02 offset sums from nci/offset.R (BoM's qm43 L3S
# SST, BoM ABOM GHRSST L3S 1-day day+night, not MUR).
#
# d = fv01 - fv02 (degrees C) on pixels valid in both versions under the
# variant (all / q4 / q4b). From the pooled sums of each group:
#   offset       paired mean of d (area-weighted)        sumwd / sumw_both
#   sd_pixel     spread of d over paired pixels          sqrt(sumwd2/sumw_both - offset^2)
#   naive        mean of fv01 on its own pixels minus mean of fv02 on its own pixels:
#                what a splice of the two records' own means would see
#   selection    naive - offset: the part of naive due to the two versions keeping different pixels
#   n01_per_n02  how many pixels fv01 keeps per fv02 pixel
#   paired_of_02 share of fv02's pixels that fv01 also has
# Daily means of d (domain and region sets except amp, which is monthly only):
#   day_mean, day_sd  mean and sd over days of the daily paired offset
#
# Writes (committed):
#   nci/offset_by_region.csv          product x variant x set x region, all overlap days
#   nci/offset_by_year.csv            the same per year, for domain, eez_legal and star
#   nci/offset_domain_monthly.csv     product x variant x month, whole domain
# and data/nci/offset_s2l5.csv         product x variant x S2 L5 cell (for maps)
#
# usage (from the repo root): Rscript nci/offset_summary.R [data/nci/offset]
args <- commandArgs(TRUE)
dir <- if (length(args)) args[1] else "data/nci/offset"
files <- Sys.glob(file.path(dir, "*", "*.rds"))
if (!length(files)) stop("no offset files under ", dir)
res <- lapply(files, readRDS)
cat("product-months:", length(res), "\n")
pick <- function(n) do.call(rbind, lapply(res, function(r) if (!is.null(r[[n]])) cbind(product = r$product, r[[n]])))
days <- pick("days"); daily <- pick("regions"); monthly <- pick("regions_month"); s2 <- pick("s2")
cols <- c("n_both", "sumw_both", "sumwd", "sumwd2", "sumwx02_both", "n_01", "sumw_01", "sumwx_01", "sumwx2_01",
          "n_02", "sumw_02", "sumwx_02", "sumwx2_02")

## the day log
days$ok <- days$error == ""
cat("days:", nrow(days), " failed:", sum(!days$ok), "\n")
if (any(!days$ok)) print(head(days[!days$ok, c("product", "date", "error")], 20), row.names = FALSE)
print(aggregate(cbind(days = ok, seconds = seconds, read_s = read_s) ~ product, transform(days, ok = as.numeric(ok)),
                function(x) round(c(sum = sum(x), mean = mean(x)), 1))[, 1:4], row.names = FALSE)

regions <- read.csv("boundaries/regions.csv")[c("set", "region_id", "region")]
regions <- rbind(regions, data.frame(set = "domain", region_id = 1L, region = "whole window"))
win <- c(cont_avhrr = "Continental 70-190E 70S-20N", cont_multi = "Continental 70-190E 70S-20N",
         south_avhrr = "Southern 2.5-202.5E 77.5S-27.5S", south_multi = "Southern 2.5-202.5E 77.5S-27.5S")

## pooled sums -> statistics
pool <- function(x, by) {
  s <- aggregate(x[cols], x[by], sum)
  s$offset <- s$sumwd / s$sumw_both
  s$sd_pixel <- sqrt(pmax(s$sumwd2 / s$sumw_both - s$offset^2, 0))
  s$fv02_paired_mean <- s$sumwx02_both / s$sumw_both
  s$fv01_own_mean <- s$sumwx_01 / s$sumw_01
  s$fv02_own_mean <- s$sumwx_02 / s$sumw_02
  s$naive <- s$fv01_own_mean - s$fv02_own_mean
  s$selection <- s$naive - s$offset
  s$n01_per_n02 <- s$n_01 / s$n_02
  s$paired_of_02 <- s$n_both / s$n_02
  s
}
daystats <- function(x, by) {   # over days, of the daily paired offset
  x$m <- x$sumwd / x$sumw_both
  x <- x[is.finite(x$m), ]
  a <- aggregate(x["m"], x[by], function(m) c(days = length(m), day_mean = mean(m), day_sd = sd(m)))
  cbind(a[by], as.data.frame(a$m))
}
tidy <- function(s, extra = character()) {
  s <- merge(s, regions, by = c("set", "region_id"), all.x = TRUE)
  s$region[s$set == "domain"] <- win[s$product[s$set == "domain"]]
  keep <- c("product", "variant", "set", "region_id", "region", extra, "days", "day_mean", "day_sd",
            "offset", "sd_pixel", "fv02_paired_mean", "fv01_own_mean", "fv02_own_mean", "naive", "selection",
            "n01_per_n02", "paired_of_02", "n_both", "sumw_both")
  s <- s[intersect(keep, names(s))]
  num <- vapply(s, is.numeric, logical(1)) & !names(s) %in% c("region_id", "days", "n_both", "sumw_both")
  s[num] <- lapply(s[num], signif, 5)
  s
}

## 1. all overlap days, every region (monthly sums include amp)
by <- c("product", "variant", "set", "region_id")
s <- pool(monthly, by)
s$days <- aggregate(monthly["days"], monthly[by], sum)$days[match(do.call(paste, s[by]), do.call(paste, aggregate(monthly["days"], monthly[by], sum)[by]))]
d <- daystats(daily, by)
s <- merge(s, d[c(by, "day_mean", "day_sd")], by = by, all.x = TRUE)
out1 <- tidy(s); out1 <- out1[order(out1$product, out1$variant, out1$set, out1$region_id), ]
write.csv(out1, "nci/offset_by_region.csv", row.names = FALSE)

## 2. per year, domain + eez_legal + star
monthly$year <- substr(monthly$month, 1, 4); daily$year <- format(as.Date(daily$date), "%Y")
mY <- monthly[monthly$set %in% c("domain", "eez_legal", "star"), ]
byY <- c(by, "year")
sY <- pool(mY, byY)
dY <- daystats(daily[daily$set %in% c("domain", "eez_legal", "star"), ], byY)
sY <- merge(sY, dY, by = byY, all.x = TRUE)
out2 <- tidy(sY, "year"); out2 <- out2[order(out2$product, out2$variant, out2$set, out2$region_id, out2$year), ]
write.csv(out2, "nci/offset_by_year.csv", row.names = FALSE)

## 3. domain, monthly
mD <- monthly[monthly$set == "domain", ]
byM <- c(by, "month")
sM <- pool(mD, byM)
dM <- daystats(daily[daily$set == "domain", ] |> transform(month = format(as.Date(date), "%Y-%m")), byM)
sM <- merge(sM, dM, by = byM, all.x = TRUE)
out3 <- tidy(sM, "month"); out3 <- out3[order(out3$product, out3$variant, out3$month), ]
out3$set <- NULL; out3$region_id <- NULL
write.csv(out3, "nci/offset_domain_monthly.csv", row.names = FALSE)

## 4. S2 L5 cells, pooled (not committed)
sC <- pool(s2, c("product", "variant", "cell"))
write.csv(sC, "data/nci/offset_s2l5.csv", row.names = FALSE)

## summary: whole domain, plus the STAR regions for q4b
cat("\nwhole domain, all overlap days (d = fv01 - fv02, degrees C):\n")
print(out1[out1$set == "domain", c("product", "variant", "days", "offset", "sd_pixel", "day_sd", "naive", "selection", "n01_per_n02", "paired_of_02")], row.names = FALSE)
cat("\nSTAR regions, q4b:\n")
print(out1[out1$set == "star" & out1$variant == "q4b", c("product", "region", "days", "offset", "day_sd", "naive", "selection", "n01_per_n02")], row.names = FALSE)
