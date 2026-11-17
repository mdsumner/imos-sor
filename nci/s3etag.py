"""S3-style ETags of local files, to match NCI copies against s3://imos-data
without downloading anything.

The imos-data objects were uploaded three ways, so one file can carry any of
these ETags:
  - single PUT: md5 of the file (no "-N")
  - 15 MiB multipart parts (s3cmd's default chunk), older objects
  - 8 MiB multipart parts (aws cli default), newer objects
A multipart ETag is md5(concat(md5(part_i))) + "-" + nparts. One pass over each
file computes them all.
Prints: path<TAB>size<TAB>md5<TAB>etag_8MiB<TAB>etag_15MiB<TAB>etag_16MiB

usage: python3 -I s3etag.py < paths.txt > etags.tsv
"""
import sys, hashlib, os

MiB = 1024 * 1024
PARTS = (8, 15, 16)          # MiB; all multiples of the 1 MiB read block

def etags(path):
    whole = hashlib.md5()
    cur = {p: hashlib.md5() for p in PARTS}
    fill = {p: 0 for p in PARTS}
    digests = {p: [] for p in PARTS}
    with open(path, "rb") as f:
        while True:
            b = f.read(MiB)
            if not b:
                break
            whole.update(b)
            for p in PARTS:
                cur[p].update(b)
                fill[p] += len(b)
                if fill[p] == p * MiB:
                    digests[p].append(cur[p].digest())
                    cur[p] = hashlib.md5(); fill[p] = 0
    out = [whole.hexdigest()]
    for p in PARTS:
        d = digests[p] + ([cur[p].digest()] if fill[p] else [])
        out.append(whole.hexdigest() if len(d) <= 1 else hashlib.md5(b"".join(d)).hexdigest() + "-" + str(len(d)))
    return out

def main():
    for line in sys.stdin:
        p = line.strip().split("\t")[0]
        if not p:
            continue
        try:
            print("\t".join([p, str(os.path.getsize(p))] + etags(p)), flush=True)
        except OSError as e:
            print(f"{p}\tNA\tERROR {e}", flush=True)

if __name__ == "__main__":
    main()
