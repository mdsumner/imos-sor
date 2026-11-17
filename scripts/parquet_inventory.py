"""Harvest structure of every Parquet dataset in s3://aodn-cloud-optimised.

Per dataset: number of files, total bytes, hive partition keys and the count /
range of each key's values, plus the schema (column names) and row count of
one sample file, and selected key/value metadata. Anonymous access.

usage: python3 -I parquet_inventory.py <listing.txt> <out.csv>
"""
import sys, json, csv
from collections import defaultdict
import s3fs
import pyarrow.parquet as pq

BUCKET = "aodn-cloud-optimised"
fs = s3fs.S3FileSystem(anon=True, client_kwargs={"region_name": "ap-southeast-2"})

def datasets(listing):
    return [l.split()[-1].rstrip("/") for l in open(listing) if l.split()[-1].rstrip("/").endswith(".parquet")]

def summarise(name):
    root = f"{BUCKET}/{name}"
    files = fs.find(root, detail=True)
    pfiles = {k: v for k, v in files.items() if k.endswith(".parquet") or "part" in k.rsplit("/", 1)[-1]}
    rec = {"dataset": name, "n_files": len(pfiles),
           "total_gb": round(sum(v.get("size", 0) for v in pfiles.values()) / 1e9, 3)}
    parts = defaultdict(set)
    for k in pfiles:
        for seg in k[len(root) + 1:].split("/")[:-1]:
            if "=" in seg:
                a, b = seg.split("=", 1)
                parts[a].add(b)
    rec["partition_keys"] = " ".join(parts)
    for a, vals in parts.items():
        vs = sorted(vals)
        rec[f"part_{a}"] = f"n={len(vs)} [{vs[0][:40]} .. {vs[-1][:40]}]"
    if pfiles:
        sample = max(pfiles, key=lambda k: pfiles[k].get("size", 0))
        with fs.open(sample) as f:
            md = pq.ParquetFile(f).metadata
            sch = pq.ParquetFile(f).schema_arrow
        rec["sample_rows"] = md.num_rows
        rec["n_columns"] = len(sch.names)
        rec["columns"] = " ".join(sch.names)[:1500]
        kv = sch.metadata or {}
        for k in list(kv)[:20]:
            ks = k.decode(errors="replace")
            if ks in ("pandas", "ARROW:schema"):
                continue
            rec[f"meta_{ks}"[:60]] = kv[k].decode(errors="replace")[:300]
    return rec

def main(listing, out):
    rows = []
    for d in datasets(listing):
        try:
            r = summarise(d)
        except Exception as e:
            r = {"dataset": d, "error": repr(e)[:300]}
        print(json.dumps(r, default=str)[:3000], flush=True)
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
