"""S3-style ETag of local files, to match NCI copies against s3://imos-data
without downloading anything.

The imos-data objects were uploaded in 8 MiB parts, so their ETag is
md5(concat(md5(part_i))) + "-" + nparts (a plain md5 for single-part
objects). Prints: path<TAB>size<TAB>etag

usage: python3 -I s3etag.py [--part-mib 8] < paths.txt > etags.tsv
"""
import sys, hashlib, os

def etag(path, part=8 * 1024 * 1024):
    digests = []
    with open(path, "rb") as f:
        while True:
            b = f.read(part)
            if not b:
                break
            digests.append(hashlib.md5(b).digest())
    if len(digests) <= 1:          # single-part upload: the ETag is the file's md5
        with open(path, "rb") as f:
            return hashlib.md5(f.read()).hexdigest()
    return hashlib.md5(b"".join(digests)).hexdigest() + "-" + str(len(digests))

def main():
    part = 8
    if len(sys.argv) > 2 and sys.argv[1] == "--part-mib":
        part = int(sys.argv[2])
    for line in sys.stdin:
        p = line.strip()
        if not p:
            continue
        try:
            print(f"{p}\t{os.path.getsize(p)}\t{etag(p, part * 1024 * 1024)}", flush=True)
        except OSError as e:
            print(f"{p}\tNA\tERROR {e}", flush=True)

if __name__ == "__main__":
    main()
