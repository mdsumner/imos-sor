"""Render the harvested inventories as markdown tables.

usage: python3 -I summarise_inventory.py <inventory_dir> <notes_dir>
writes notes/zarr_stores.md and notes/parquet_datasets.md
"""
import sys, json, os, datetime

def load(p):
    return [json.loads(l) for l in open(p) if l.startswith("{")]

def fam(name):
    return name.split("_")[0]

def yr(s):
    try:
        return datetime.datetime.fromtimestamp(int(s), datetime.UTC).year
    except Exception:
        return None

def zarr_md(rows):
    out = ["# aodn-cloud-optimised: Zarr stores", "",
           f"{len(rows)} stores, harvested {datetime.date.today()} by scripts/zarr_inventory.py "
           "(metadata + 1-D coords only). `s3://aodn-cloud-optimised/<store>`, anonymous, ap-southeast-2. "
           "All Zarr v2, consolidated, Blosc-lz4. Extent is pixel centres.", ""]
    cur = None
    for r in sorted(rows, key=lambda r: r["store"]):
        f = fam(r["store"])
        if f != cur:
            cur = f
            out += ["", f"## {f}", "",
                    "| store | shape (t,y,x) | chunks | lon | lat | step | time | uuid |",
                    "|---|---|---|---|---|---|---|---|"]
        if "error" in r:
            out.append(f"| {r['store']} | ERROR {r['error'][:60]} |||||||")
            continue
        lon = f"{r['lon_min']:.2f}..{r['lon_max']:.2f}" if "lon_min" in r else r.get("dims", "")
        lat = f"{r['lat_min']:.2f}..{r['lat_max']:.2f}" if "lat_min" in r else ""
        step = f"{r['lon_step']:.4g}" if "lon_step" in r else ""
        t = f"{r.get('time_start','')[:10]}..{r.get('time_end','')[:10]}"
        out.append(f"| {r['store'].replace('.zarr','')} | {r.get('shape','')} | {r.get('chunks','')} | {lon} | {lat} | {step} | {t} | {r.get('attr_metadata_uuid','')} |")
    return "\n".join(out) + "\n"

def parquet_md(rows):
    tot = sum(r.get("total_gb", 0) for r in rows)
    out = ["# aodn-cloud-optimised: Parquet datasets", "",
           f"{len(rows)} hive-partitioned datasets, {tot:.1f} GB total, harvested {datetime.date.today()} "
           "by scripts/parquet_inventory.py. Every dataset is also partitioned by `polygon=` "
           "(WKB hex of a spatial bounding polygon) and most by `timestamp=` (epoch seconds, year bins).", ""]
    cur = None
    for r in sorted(rows, key=lambda r: r["dataset"]):
        f = fam(r["dataset"])
        if f != cur:
            cur = f
            out += ["", f"## {f}", "", "| dataset | files | GB | cols | years | other partitions |", "|---|---|---|---|---|---|"]
        if "error" in r:
            out.append(f"| {r['dataset']} | ERROR {r['error'][:60]} |||||")
            continue
        years = ""
        ts = r.get("part_timestamp")
        if ts:
            # stored as 'n=K [a .. b]' with lexical order, recompute from range is unreliable;
            # report count only plus min/max where parseable
            years = ts.split(" ")[0]
        other = "; ".join(f"{k[5:]} {v.split(' ')[0]}" for k, v in r.items()
                          if k.startswith("part_") and k not in ("part_timestamp", "part_polygon"))
        out.append(f"| {r['dataset'].replace('.parquet','')} | {r['n_files']} | {r['total_gb']:.2f} | {r.get('n_columns','')} | {years} | {other} |")
    return "\n".join(out) + "\n"

def main(inv, notes):
    z = load(os.path.join(inv, "zarr_inventory.jsonl"))
    p = load(os.path.join(inv, "parquet_inventory.jsonl"))
    open(os.path.join(notes, "zarr_stores.md"), "w").write(zarr_md(z))
    open(os.path.join(notes, "parquet_datasets.md"), "w").write(parquet_md(p))
    print(len(z), "zarr;", len(p), "parquet")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
