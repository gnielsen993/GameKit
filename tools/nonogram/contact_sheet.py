#!/usr/bin/env python3
"""
contact_sheet.py — pack candidate thumbnails into grid contact sheets so a
reviewer can scan 36 candidates per image instead of opening 36 PNGs.
Reads /tmp/nonogram-thumbs/<size>/*.png plus the candidates-<n>.json file
and writes /tmp/nonogram-contact/<size>-<page>.png plus an index.json
mapping each cell-position back to its candidate id.

Usage:
    python3 contact_sheet.py
"""

import json
import os
from PIL import Image, ImageDraw, ImageFont

THUMB_DIR = "/tmp/nonogram-thumbs"
OUT_DIR = "/tmp/nonogram-contact"
COLS = 6
ROWS = 6
CELL_PX = 180          # rendered cell side
LABEL_PX = 22          # label band height per cell
GUTTER = 6             # px between cells

SIZES = [5, 10, 15, 20]


def load_candidates(n: int) -> list[dict]:
    path = os.path.join(THUMB_DIR, f"candidates-{n}.json")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return json.load(f)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    index: dict[str, list[dict]] = {}

    for n in SIZES:
        cands = load_candidates(n)
        if not cands:
            continue
        per_page = COLS * ROWS
        pages = (len(cands) + per_page - 1) // per_page
        page_index: list[dict] = []

        for page in range(pages):
            page_cands = cands[page * per_page:(page + 1) * per_page]

            sheet_w = COLS * (CELL_PX + GUTTER) + GUTTER
            sheet_h = ROWS * (CELL_PX + LABEL_PX + GUTTER) + GUTTER + 30
            sheet = Image.new("RGB", (sheet_w, sheet_h), color=(245, 240, 232))
            draw = ImageDraw.Draw(sheet)
            try:
                font = ImageFont.truetype(
                    "/System/Library/Fonts/Helvetica.ttc", size=14)
                title_font = ImageFont.truetype(
                    "/System/Library/Fonts/HelveticaNeue.ttc", size=18)
            except OSError:
                font = ImageFont.load_default()
                title_font = font

            draw.text(
                (GUTTER, 4),
                f"{n}×{n}  page {page + 1}/{pages}  ({len(cands)} candidates)",
                fill=(40, 40, 40),
                font=title_font,
            )

            for i, cand in enumerate(page_cands):
                col = i % COLS
                row = i // COLS
                x = GUTTER + col * (CELL_PX + GUTTER)
                y = 30 + GUTTER + row * (CELL_PX + LABEL_PX + GUTTER)

                # Slot frame
                draw.rectangle(
                    (x, y, x + CELL_PX, y + CELL_PX + LABEL_PX),
                    outline=(200, 195, 188), width=1,
                )

                thumb_path = os.path.join(THUMB_DIR, str(n), f"{cand['id']}.png")
                if os.path.exists(thumb_path):
                    thumb = Image.open(thumb_path).convert("RGB")
                    thumb = thumb.resize((CELL_PX, CELL_PX), Image.NEAREST)
                    sheet.paste(thumb, (x, y))

                # Slot number 1-36 (matches reviewer's accept list)
                slot_no = i + 1
                draw.text(
                    (x + 4, y + CELL_PX + 2),
                    f"#{slot_no}  {cand['title'][:18]}",
                    fill=(60, 60, 60), font=font,
                )

                page_index.append({
                    "page": page + 1,
                    "slot": slot_no,
                    "id": cand["id"],
                    "title": cand["title"],
                    "topic": cand.get("topic", ""),
                })

            sheet_path = os.path.join(OUT_DIR, f"{n}-{page + 1:02d}.png")
            sheet.save(sheet_path, optimize=True)

        index[str(n)] = page_index

    with open(os.path.join(OUT_DIR, "index.json"), "w") as f:
        json.dump(index, f, indent=2)

    for n, items in index.items():
        page_count = max(it["page"] for it in items) if items else 0
        print(f"{n}×{n}: {len(items)} candidates across {page_count} sheets")


if __name__ == "__main__":
    main()
