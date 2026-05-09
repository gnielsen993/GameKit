#!/usr/bin/env python3
"""
svg_to_grid.py — render every SVG in /tmp/nonogram-source/ to N×N 1-bit
grids (N ∈ {5, 10, 15, 20}), apply legibility + uniqueness heuristics, emit
candidate bitstrings + thumbnail PNGs into /tmp/nonogram-thumbs/<size>/.

Heuristics dropped:
  - density outside [0.25, 0.75]
  - ≥1 row OR ≥1 col fully filled or fully empty (boring at the edge)
  - all clue rows trivial (single-run only) AT 10×10+ (tiny is allowed)
  - duplicate bitstring across already-emitted candidates

Run:
    python3 svg_to_grid.py
"""

import json
import os
import sys
from io import BytesIO

import cairosvg
from PIL import Image

SRC_DIR = "/tmp/nonogram-source"
OUT_DIR = "/tmp/nonogram-thumbs"
SIZES = [5, 10, 15, 20]
SIZE_TO_BUCKET = {5: "tiny", 10: "small", 15: "medium", 20: "large"}

# Render the SVG at this many pixels per cell, then box-downsample to size.
# Higher OVERSAMPLE = better antialiasing → cleaner threshold at small N.
# 40+ is needed so detail-heavy SVGs collapse to a clean silhouette instead
# of high-frequency noise.
OVERSAMPLE = 48


def render_svg_to_grid(svg_path: str, n: int) -> str | None:
    """Render `svg_path` to an N×N 1-bit grid. Return row-major "0"/"1"
    bitstring of length n*n, or None on render failure."""
    try:
        png_bytes = cairosvg.svg2png(
            url=svg_path,
            output_width=n * OVERSAMPLE,
            output_height=n * OVERSAMPLE,
            background_color="white",
        )
    except Exception:
        return None
    img = Image.open(BytesIO(png_bytes)).convert("L")
    # box-resize to N×N, then threshold at 128
    small = img.resize((n, n), Image.LANCZOS)
    pixels = list(small.getdata())
    # Filled = dark (silhouette-on-white). Threshold at 200 to favor catching
    # more shape; cleaner SVGs land well inside the band anyway.
    bits = "".join("1" if px < 200 else "0" for px in pixels)
    return bits


def density(bits: str) -> float:
    return bits.count("1") / max(1, len(bits))


def count_components(bits: str, n: int) -> int:
    """4-connected flood-fill component count over filled cells. Recognizable
    silhouettes have 1-3 components (face: head + 2 eyes; cat: body + tail)."""
    seen = [False] * (n * n)
    components = 0
    for start in range(n * n):
        if bits[start] != "1" or seen[start]:
            continue
        components += 1
        stack = [start]
        seen[start] = True
        while stack:
            i = stack.pop()
            r, c = divmod(i, n)
            for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nr, nc = r + dr, c + dc
                if 0 <= nr < n and 0 <= nc < n:
                    j = nr * n + nc
                    if bits[j] == "1" and not seen[j]:
                        seen[j] = True
                        stack.append(j)
    return components


def edge_flips(bits: str, n: int) -> int:
    """Total horizontal + vertical 0/1 transitions. High = noisy speckle."""
    flips = 0
    for r in range(n):
        for c in range(n - 1):
            if bits[r * n + c] != bits[r * n + c + 1]:
                flips += 1
    for c in range(n):
        for r in range(n - 1):
            if bits[r * n + c] != bits[(r + 1) * n + c]:
                flips += 1
    return flips


def all_runs(line: str) -> list[int]:
    """Run-length list of 1s in a line."""
    runs: list[int] = []
    cur = 0
    for ch in line:
        if ch == "1":
            cur += 1
        elif cur:
            runs.append(cur)
            cur = 0
    if cur:
        runs.append(cur)
    return runs


def is_legible(bits: str, n: int) -> tuple[bool, str]:
    d = density(bits)
    if d < 0.18 or d > 0.72:
        return False, f"density={d:.2f}"
    rows = [bits[i * n:(i + 1) * n] for i in range(n)]
    cols = ["".join(bits[r * n + c] for r in range(n)) for c in range(n)]
    # Anti-padding — too many fully-empty rows/cols means the icon sits in
    # whitespace. Some empty rows are fine (silhouettes have headroom).
    if n >= 10:
        if sum(1 for r in rows if r == "0" * n) > n // 2:
            return False, "too many empty rows"
        if sum(1 for c in cols if c == "0" * n) > n // 2:
            return False, "too many empty cols"
    # Anti-noise — connected components + edge-flip ratio. Silhouettes have
    # 1-3 components and low flip ratio; thresholded line-art / text has 8+
    # components and very high flip ratio.
    comp = count_components(bits, n)
    flips = edge_flips(bits, n)
    cells = n * n
    flip_ratio = flips / max(1, cells * 2)
    max_comp = 3 if n <= 5 else 5 if n <= 10 else 7
    if comp > max_comp:
        return False, f"components={comp} (max {max_comp})"
    if flip_ratio > 0.40:
        return False, f"flips={flip_ratio:.2f}"
    return True, "ok"


def main() -> None:
    if not os.path.isdir(SRC_DIR):
        print(f"no source dir at {SRC_DIR} — run fetch_cc0.py first")
        sys.exit(1)
    os.makedirs(OUT_DIR, exist_ok=True)
    for n in SIZES:
        os.makedirs(os.path.join(OUT_DIR, str(n)), exist_ok=True)

    seen_bits: dict[int, set[str]] = {n: set() for n in SIZES}
    candidates: dict[int, list[dict]] = {n: [] for n in SIZES}

    total_svgs = 0
    for topic in sorted(os.listdir(SRC_DIR)):
        topic_dir = os.path.join(SRC_DIR, topic)
        if not os.path.isdir(topic_dir):
            continue
        for fn in sorted(os.listdir(topic_dir)):
            if not fn.endswith(".svg"):
                continue
            svg_path = os.path.join(topic_dir, fn)
            meta_path = svg_path + ".meta.json"
            try:
                with open(meta_path) as mf:
                    meta = json.load(mf)
            except FileNotFoundError:
                meta = {"id": fn[:-4], "title": topic, "topic": topic}
            total_svgs += 1
            for n in SIZES:
                bits = render_svg_to_grid(svg_path, n)
                if bits is None:
                    continue
                if bits in seen_bits[n]:
                    continue
                ok, why = is_legible(bits, n)
                if not ok:
                    continue
                seen_bits[n].add(bits)
                cand_id = f"{SIZE_TO_BUCKET[n]}-{topic}-{meta['id'][:8]}"
                candidates[n].append({
                    "id": cand_id,
                    "title": (meta.get("title") or topic).strip()[:40] or topic,
                    "grid": bits,
                    "topic": topic,
                    "source_url": meta.get("source_url"),
                    "creator": meta.get("creator"),
                })
                # Save thumbnail PNG (10× upscale w/ nearest neighbor → crisp).
                thumb = Image.new("L", (n, n), 255)
                thumb.putdata([0 if b == "1" else 255 for b in bits])
                thumb = thumb.resize((n * 12, n * 12), Image.NEAREST)
                thumb.save(os.path.join(OUT_DIR, str(n), f"{cand_id}.png"))

    for n in SIZES:
        with open(os.path.join(OUT_DIR, f"candidates-{n}.json"), "w") as f:
            json.dump(candidates[n], f, indent=2)

    print(f"\nProcessed {total_svgs} SVGs.")
    for n in SIZES:
        print(f"  {n}×{n}: {len(candidates[n])} legible candidates")


if __name__ == "__main__":
    main()
