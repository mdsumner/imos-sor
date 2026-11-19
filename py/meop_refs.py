"""Byte references and a profile index for IMOS's MEOP-QC'd seal and turtle
CTD profiles (s3://imos-data/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/,
also /g/data/sh74/IMOS_AODN/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/).

The files are classic netCDF-3 (CDF-1): uncompressed, big-endian, no record
dimension, so every variable is one contiguous byte range and any run of whole
profiles of a (N_PROF, N_LEVELS) array is too (row i at begin + i * N_LEVELS *
itemsize). kerchunk's netCDF-3 reader gives each variable's begin and size
(GDAL's netCDF driver has no GetRawBlockInfo for classic files). Header reads
only, plus five 1-D arrays per file for the index: about 2 minutes for the
564 files from outside AWS.

Writes data/animal/meop_scan.jsonl (one line per file: global attributes, and
per array shape, dtype, dims and [url, offset, size]) and
data/animal/meop_profiles_raw.parquet (one row per profile: file, row, cycle,
JULD, LATITUDE, LONGITUDE, POSITION_QC and the file's species, location,
deployment and release). R/14_meop_cells.R screens positions and adds S2 L5
cells.

usage (from the repo root): python3 py/meop_refs.py [listing]
  listing: `aws s3 ls --recursive` of the MEOP_QC_CTD prefix; default
  data/animal/meop_listing.txt, made here if missing.
"""
import concurrent.futures as cf, json, os, subprocess, sys
import fsspec, numpy as np, pyarrow as pa, pyarrow.parquet as pq
from kerchunk.netCDF3 import NetCDF3ToZarr

PREFIX = "s3://imos-data/IMOS/AATAMS/satellite_tagging/MEOP_QC_CTD/"
SO = {"anon": True, "client_kwargs": {"region_name": "ap-southeast-2"}}
lst = sys.argv[1] if len(sys.argv) > 1 else "data/animal/meop_listing.txt"
os.makedirs("data/animal", exist_ok=True)
if not os.path.exists(lst):
    with open(lst, "w") as f:
        subprocess.run(["aws", "s3", "ls", "--no-sign-request", "--region", "ap-southeast-2", "--recursive", PREFIX], stdout=f, check=True)
keys = [l.split()[3] for l in open(lst) if l.strip().endswith(".nc")]
print(len(keys), "files")

def scan(k):
    r = NetCDF3ToZarr("s3://imos-data/" + k, storage_options=SO, inline_threshold=0).translate()["refs"]
    attrs = json.loads(r[".zattrs"]) if isinstance(r[".zattrs"], str) else r[".zattrs"]
    arrays = {}
    for name in sorted({p.split("/")[0] for p in r if "/" in p}):
        if name + "/.zarray" not in r: continue
        za = json.loads(r[name + "/.zarray"]); zt = json.loads(r.get(name + "/.zattrs", "{}"))
        ch = [v for p, v in r.items() if p.startswith(name + "/") and not p.split("/")[1].startswith(".")]
        assert len(ch) == 1 and isinstance(ch[0], list), (k, name)   # one contiguous chunk per variable
        arrays[name] = {"shape": za["shape"], "dtype": za["dtype"], "fill": za["fill_value"],
                        "dims": zt.get("_ARRAY_DIMENSIONS"), "ref": ch[0]}
    return {"key": k, "attrs": attrs, "arrays": arrays}

with cf.ThreadPoolExecutor(32) as ex:
    files = list(ex.map(scan, keys))
with open("data/animal/meop_scan.jsonl", "w") as f:
    for x in files: f.write(json.dumps(x) + "\n")

fs = fsspec.filesystem("s3", **SO)
V = {"JULD": ">f8", "LATITUDE": ">f8", "LONGITUDE": ">f8", "CYCLE_NUMBER": ">i4", "POSITION_QC": "|S1"}
def index(x):
    a = x["arrays"]; at = x["attrs"]; url = "imos-data/" + x["key"]
    got = fs.cat_ranges([url] * len(V), [a[n]["ref"][1] for n in V], [a[n]["ref"][1] + a[n]["ref"][2] for n in V])
    d = {n: np.frombuffer(b, dtype=V[n]) for n, b in zip(V, got)}
    n = len(d["JULD"])
    rep = lambda v: [v] * n
    return {"key": rep(x["key"]), "smru": rep(at.get("smru_platform_code")), "wmo": rep(at.get("wmo_platform_code")),
            "species_label": rep(at.get("species")), "location": rep(at.get("location")), "deployment": rep(at.get("deployment_code")),
            "release": rep(at.get("version_database")), "n_levels": rep(a["TEMP_ADJUSTED"]["shape"][1]),
            "row": list(range(n)), "cycle": d["CYCLE_NUMBER"].tolist(), "juld": d["JULD"].tolist(),
            "lat": d["LATITUDE"].tolist(), "lon": d["LONGITUDE"].tolist(), "position_qc": d["POSITION_QC"].astype(str).tolist()}
with cf.ThreadPoolExecutor(32) as ex:
    parts = list(ex.map(index, files))
cols = {k: sum((p[k] for p in parts), []) for k in parts[0]}
t = pa.table(cols)
pq.write_table(t, "data/animal/meop_profiles_raw.parquet")
print(t.num_rows, "profiles -> data/animal/meop_profiles_raw.parquet")
