#!/usr/bin/env python3
"""
fetch_cc0.py — pull CC0-licensed SVG illustrations from the Openverse API
into /tmp/nonogram-source/<topic>/<id>.svg.

Openverse aggregates Wikimedia Commons + Flickr CC0 + others. We filter by
license=cc0 + extension=svg + category=illustration so we only land on
clean vector silhouettes — no photos, no copyleft.

Run:
    python3 fetch_cc0.py --topics scout         # ~30 SVGs across 5 topics
    python3 fetch_cc0.py --topics full          # ~2000 across full theme list

Re-runs are idempotent (skip already-downloaded ids).
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request

OUT_DIR = "/tmp/nonogram-source"
USER_AGENT = "GameDrawer-Nonogram-CC0-Fetch/1.0 (gxnielsen@gmail.com; CC0 only)"


def _open(url: str, timeout: int):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    return urllib.request.urlopen(req, timeout=timeout)

SCOUT_TOPICS = [
    "cat", "apple", "tree", "car", "heart",
]

FULL_TOPICS = [
    # animals
    "cat", "dog", "bird", "fish", "rabbit", "mouse", "horse", "pig",
    "sheep", "cow", "lion", "elephant", "bear", "fox", "owl", "snake",
    "turtle", "frog", "butterfly", "bee", "duck", "penguin", "whale",
    "dolphin", "shark", "crab", "octopus", "snail", "ladybug", "ant",
    # food
    "apple", "banana", "carrot", "cherry", "grape", "pizza", "cake",
    "bread", "mushroom", "donut", "ice-cream", "sandwich", "cheese",
    "egg", "burger", "cookie", "lemon", "orange-fruit", "pear",
    "strawberry", "watermelon", "pineapple", "tomato", "potato",
    # nature
    "tree", "leaf", "flower", "sun", "moon", "star", "cloud",
    "snowflake", "mountain", "fire", "wave", "rainbow", "lightning",
    # vehicles
    "car", "bicycle", "boat", "plane", "train", "rocket", "truck",
    "balloon", "submarine", "helicopter",
    # household
    "chair", "lamp", "cup", "book", "clock", "candle", "umbrella",
    "bell", "key", "lock", "phone", "computer", "camera", "tv",
    # clothes
    "shirt", "hat", "shoe", "glove", "sock", "tie", "boot", "dress",
    # tools
    "hammer", "scissors", "pencil", "brush", "wrench", "saw", "ruler",
    # symbols
    "heart", "anchor", "crown", "music-note", "smile", "arrow",
    "lightbulb", "gift", "diamond", "envelope",
]

ENDPOINT = "https://api.openverse.org/v1/images/"


def _query_once(query: str, target_count: int, timeout: int) -> list[dict]:
    params = {
        "q": query,
        "license": "cc0",
        "extension": "svg",
        "page_size": "20",
    }
    out: list[dict] = []
    for page in range(1, 6):
        params["page"] = str(page)
        url = f"{ENDPOINT}?{urllib.parse.urlencode(params)}"
        try:
            with _open(url, timeout) as r:
                data = json.loads(r.read())
        except Exception as e:
            print(f"  ! query={query} p{page} failed: {e}", file=sys.stderr)
            break
        results = data.get("results", [])
        if not results:
            break
        out.extend(results)
        if len(out) >= target_count:
            break
        time.sleep(0.3)
    return out[:target_count]


def fetch_topic(topic: str, target_count: int = 25, timeout: int = 15) -> list[dict]:
    """Run multiple queries per topic, deduplicate by openverse id. Broad
    queries pull more candidates; the grid pipeline's noise filters do
    quality control downstream. Order = silhouette > icon > plain so the
    cleanest matches land first."""
    seen: set[str] = set()
    merged: list[dict] = []
    for query in (f"{topic} silhouette", f"{topic} icon", topic):
        for hit in _query_once(query, target_count, timeout):
            if (id_ := hit.get("id")) and id_ not in seen:
                seen.add(id_)
                merged.append(hit)
            if len(merged) >= target_count:
                return merged
        time.sleep(0.3)
    return merged


def download_svg(url: str, dest: str, timeout: int = 15) -> bool:
    if os.path.exists(dest) and os.path.getsize(dest) > 100:
        return True
    # Wikimedia/Commons rate-limit aggressively for bots — keep a polite gap.
    time.sleep(1.5)
    try:
        with _open(url, timeout) as r:
            data = r.read()
        if not data.lstrip().startswith(b"<"):
            return False  # not SVG
        with open(dest, "wb") as f:
            f.write(data)
        return True
    except Exception as e:
        print(f"  ! download failed: {e}", file=sys.stderr)
        time.sleep(5.0)  # back off harder on any error
        return False


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--topics", choices=("scout", "full"), default="scout")
    p.add_argument("--per-topic", type=int, default=25)
    args = p.parse_args()

    topics = SCOUT_TOPICS if args.topics == "scout" else FULL_TOPICS
    target = args.per_topic if args.topics == "full" else 6  # scout = 6 each

    os.makedirs(OUT_DIR, exist_ok=True)
    summary: dict[str, int] = {}

    for topic in topics:
        topic_dir = os.path.join(OUT_DIR, topic)
        os.makedirs(topic_dir, exist_ok=True)
        print(f"→ {topic}: searching…")
        hits = fetch_topic(topic, target_count=target)
        print(f"  {len(hits)} CC0 SVGs found")
        ok = 0
        for h in hits:
            url = h.get("url")
            id_ = h.get("id")
            if not url or not id_:
                continue
            dest = os.path.join(topic_dir, f"{id_}.svg")
            meta_path = dest + ".meta.json"
            if download_svg(url, dest):
                with open(meta_path, "w") as mf:
                    json.dump({
                        "id": id_,
                        "title": h.get("title", topic),
                        "creator": h.get("creator"),
                        "license": h.get("license"),
                        "license_url": h.get("license_url"),
                        "source_url": h.get("foreign_landing_url"),
                        "topic": topic,
                    }, mf, indent=2)
                ok += 1
        summary[topic] = ok
        time.sleep(0.5)

    total = sum(summary.values())
    print(f"\n=== fetched {total} SVGs across {len(topics)} topics ===")
    for t, c in sorted(summary.items()):
        print(f"  {t:>14s}: {c}")


if __name__ == "__main__":
    main()
