"""Harvest structural metadata from every Zarr store in s3://aodn-cloud-optimised.

For each store: zarr format, variables, dims/shape/chunks/dtype of the largest
array, lon/lat extent and spacing, time span and step, and a few global attrs.
Reads only metadata plus the 1-D coordinate arrays. Anonymous access.

usage: python3 -I zarr_inventory.py <listing.txt> <out.csv>
"""
import sys, json, csv, traceback
import numpy as np
import s3fs
import zarr

BUCKET = "aodn-cloud-optimised"
fs = s3fs.S3FileSystem(anon=True, client_kwargs={"region_name": "ap-southeast-2"})

def stores(listing):
    out = []
    for line in open(listing):
        name = line.split()[-1].rstrip("/")
        if name.endswith(".zarr"):
            out.append(name)
    return out

def coord(g, names):
    for n in names:
        if n in g:
            return n, g[n]
    return None, None

def summarise(name):
    root = f"{BUCKET}/{name}"
    store = zarr.storage.FsspecStore(fs, path=root, read_only=True)
    g = zarr.open_group(store, mode="r")
    rec = {"store": name, "zarr_format": g.metadata.zarr_format}
    arrs = {k: v for k, v in g.arrays()}
    rec["variables"] = " ".join(sorted(arrs))
    big = max(arrs.values(), key=lambda a: int(np.prod(a.shape)) if a.shape else 0)
    rec["main_var"] = big.basename
    rec["dims"] = " ".join(big.metadata.dimension_names or []) if hasattr(big.metadata, "dimension_names") and big.metadata.dimension_names else str(big.attrs.get("_ARRAY_DIMENSIONS", ""))
    rec["shape"] = "x".join(map(str, big.shape))
    rec["chunks"] = "x".join(map(str, big.chunks))
    rec["dtype"] = str(big.dtype)
    try:
        rec["compressor"] = str(getattr(big, "compressors", "") )[:80]
    except Exception:
        rec["compressor"] = ""
    for key, names in (("lon", ("lon", "longitude", "LONGITUDE")), ("lat", ("lat", "latitude", "LATITUDE"))):
        n, a = coord(arrs, names)
        if a is not None and a.ndim == 1 and a.shape[0] > 1:
            v = a[:]
            rec[f"{key}_min"] = float(np.nanmin(v)); rec[f"{key}_max"] = float(np.nanmax(v))
            rec[f"{key}_n"] = a.shape[0]
            rec[f"{key}_step"] = float(np.round(np.nanmedian(np.abs(np.diff(v))), 6))
    n, t = coord(arrs, ("time", "TIME"))
    if t is not None and t.ndim == 1:
        units = t.attrs.get("units", "")
        rec["time_units"] = units
        rec["time_n"] = t.shape[0]
        try:
            v = t[:]
            import cftime
            cal = t.attrs.get("calendar", "standard")
            d0, d1 = cftime.num2date([np.nanmin(v), np.nanmax(v)], units, cal)
            rec["time_start"] = str(d0)[:19]; rec["time_end"] = str(d1)[:19]
            if v.size > 1:
                rec["time_step_median"] = float(np.nanmedian(np.diff(np.sort(v))))
        except Exception as e:
            rec["time_start"] = f"ERR {e}"[:60]
    ga = dict(g.attrs)
    for k in ("title", "geospatial_lat_min", "geospatial_lat_max", "geospatial_lon_min", "geospatial_lon_max", "metadata_uuid", "license"):
        if k in ga:
            rec[f"attr_{k}"] = str(ga[k])[:200]
    return rec

def main(listing, out):
    rows = []
    for s in stores(listing):
        try:
            r = summarise(s)
        except Exception as e:
            r = {"store": s, "error": repr(e)[:300]}
        print(json.dumps(r, default=str), flush=True)
        rows.append(r)
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader(); w.writerows(rows)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
