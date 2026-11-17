"""Map each aodn_cloud_optimised dataset config to its source and catalogue record.

Reads the JSON configs in a checkout of github.com/aodn/aodn_cloud_optimised
(aodn_cloud_optimised/config/dataset/*.json) and writes one row per config:
dataset_name, format, metadata_uuid, source s3 prefixes, year_range, title.
Configs with a parent ("parent_config") inherit unspecified fields; we only
record what is stated in each file plus the parent name.

usage: python3 -I config_provenance.py <config_dir> <out.csv>
"""
import sys, json, csv, glob, os

def main(cfgdir, out):
    rows = []
    for f in sorted(glob.glob(os.path.join(cfgdir, "*.json"))):
        try:
            d = json.load(open(f))
        except Exception as e:
            rows.append({"config": os.path.basename(f), "error": repr(e)[:200]})
            continue
        rs = d.get("run_settings", {}) or {}
        paths = rs.get("paths", []) or []
        rows.append({
            "config": os.path.basename(f),
            "dataset_name": d.get("dataset_name", ""),
            "parent_config": d.get("parent_config", ""),
            "format": d.get("cloud_optimised_format", ""),
            "metadata_uuid": d.get("metadata_uuid", ""),
            "catalogue_url": f"https://catalogue-imos.aodn.org.au/geonetwork/srv/eng/catalog.search#/metadata/{d['metadata_uuid']}" if d.get("metadata_uuid") else "",
            "registry_name": (d.get("aws_opendata_registry") or {}).get("Name", ""),
            "source_s3": " ".join(p.get("s3_uri", "") for p in paths if isinstance(p, dict)),
            "year_range": " ".join(str(p.get("year_range", "")) for p in paths if isinstance(p, dict) and p.get("year_range")),
        })
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=keys)
        w.writeheader(); w.writerows(rows)
    print(len(rows), "configs")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
