#!/usr/bin/env python3
"""Checks every video in Scripts/playlists/*.json against YouTube's oEmbed
endpoint: that it still exists, still allows embedding, and which channel
uploaded it. Run it before regenerating the playlist pages.

Usage: Scripts/check_playlists.py [language ...]

Exits non-zero if any video is gone or may not be embedded.
"""
import glob
import json
import os
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))


def check(video_id):
    url = ("https://www.youtube.com/oembed?format=json&url="
           f"https://www.youtube.com/watch?v={video_id}")
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            return 200, json.load(response)["author_name"]
    except urllib.error.HTTPError as error:
        return error.code, None


def main():
    langs = sys.argv[1:] or sorted(
        os.path.basename(p)[:-5] for p in glob.glob(os.path.join(HERE, "playlists", "*.json")))
    failed = 0
    for lang in langs:
        with open(os.path.join(HERE, "playlists", f"{lang}.json"), encoding="utf-8") as f:
            playlists = json.load(f)
        items = [(p["name"], v, t) for p in playlists for v, t in p["items"]]
        with ThreadPoolExecutor(8) as pool:
            results = list(pool.map(lambda item: check(item[1]), items))
        print(f"== {lang}")
        for (name, video_id, title), (status, channel) in zip(items, results):
            if status != 200:
                failed += 1
                reason = {401: "embedding not allowed", 404: "gone"}.get(status, f"HTTP {status}")
                print(f"  FAIL {name} / {title} ({video_id}): {reason}")
            else:
                print(f"  ok   {name} / {title} — {channel}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
