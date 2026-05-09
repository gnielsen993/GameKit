#!/usr/bin/env python3
"""
finalize.py — read /tmp/nonogram-thumbs/accepted-<n>.txt files (one id
per line) and emit the final tiny.json / small.json / medium.json /
large.json into the gamekit Resources/nonograms/ folder. Skips any id
not present in the candidates file.

Usage:
    python3 finalize.py
"""

import json
import os
import sys

SIZE_TO_BUCKET = {5: "tiny", 10: "small", 15: "medium", 20: "large"}
THUMB_DIR = "/tmp/nonogram-thumbs"
OUT_DIR = "/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/Resources/nonograms"


def main() -> None:
    for n in (5, 10, 15, 20):
        accept_path = os.path.join(THUMB_DIR, f"accepted-{n}.txt")
        cand_path = os.path.join(THUMB_DIR, f"candidates-{n}.json")
        if not os.path.exists(accept_path):
            print(f"  skip {n}×{n} — no accepted-{n}.txt")
            continue
        with open(accept_path) as f:
            ids = {line.strip() for line in f if line.strip() and not line.startswith("#")}
        with open(cand_path) as f:
            cands = json.load(f)

        kept = [c for c in cands if c["id"] in ids]
        kept.sort(key=lambda c: c["id"])

        # Strip metadata not needed at runtime — keep id, title, grid only.
        out = [{"id": c["id"], "title": c["title"], "grid": c["grid"]} for c in kept]

        bucket = SIZE_TO_BUCKET[n]
        out_path = os.path.join(OUT_DIR, f"{bucket}.json")
        with open(out_path, "w") as f:
            json.dump(out, f, indent=2)
        print(f"{n}×{n}: wrote {len(out)} puzzles to {bucket}.json (from {len(ids)} accepted ids)")


if __name__ == "__main__":
    main()
