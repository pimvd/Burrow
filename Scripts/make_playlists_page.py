#!/usr/bin/env python3
"""Writes website/playlists.html: ready-made playlists a parent can add to
Burrow with one tap.

Usage: Scripts/make_playlists_page.py website/playlists.html

Each playlist becomes a burrow://playlist link in the same format the app's
"Share as link" writes (see Burrow/Services/PlaylistLink.swift). Only use
uploads from the rights holder's own channel, and check in a browser that each
video still exists and allows embedding before republishing.
"""
import html
import sys
from urllib.parse import quote

PLAYLISTS = [
    {
        "name": "Julianatoren",
        "type": "video",
        "about": "Sing and dance along with Jul & Julia, from the music videos "
                 "of Kinderpretpark Julianatoren in Apeldoorn.",
        "source": "Kinderpretpark Julianatoren on YouTube",
        "items": [
            ("NiG2XOYIJ30", "De Julianatoren is té gek!"),
            ("2pnNRBN6orw", "Hieperdepiep Hoera"),
            ("7A7yp5qAmUc", "Jul & Julia en de magische Lentebloem"),
            ("wfJtPDXU0Oc", "Het is Lente"),
            ("M6hSJ-HyqqY", "Cowboydans"),
        ],
    },
    {
        "name": "Efteling",
        "type": "music",
        "about": "The music of the attractions, from the Efteling's own "
                 "soundtrack albums. Calm enough for the car or for bedtime.",
        "source": "the Efteling's soundtrack albums on YouTube",
        "items": [
            ("v9hofUN08Gw", "Carnaval Festival"),
            ("1wa2eEVR6PA", "Menuet in G – Muzikale Paddenstoelen"),
            ("uFTBxIglWCY", "Joris en de Draak"),
            ("FGA_dT-V_Hw", "De Rode Schoentjes"),
            ("HbPWLR0epTs", "De magische Klok"),
            ("yjhDUpDPfbY", "Villa Volta"),
            ("BGx_MyHJW64", "Vriendenlied"),
            ("iu7zMa7Iehg", "Winter Efteling Ouverture"),
        ],
    },
    {
        "name": "Disney",
        "type": "video",
        "about": "Favourite songs from the films, as Disney's official "
                 "music videos.",
        "source": "Disney's official YouTube channels",
        "items": [
            ("moSFlvxnbgk", "Let It Go"),
            ("cPAbx5kgCJo", "How Far I'll Go"),
            ("79DijItQXMM", "You're Welcome"),
            ("bvWRMAU6V-c", "We Don't Talk About Bruno"),
            ("c6rP-YP4c5I", "Try Everything"),
        ],
    },
]

# Same set PlaylistLink.swift leaves unescaped: letters, digits, -._~ and the
# colon that separates an item's parts.
SAFE = "-._~:"


def link(playlist):
    pairs = [("name", playlist["name"]), ("type", playlist["type"])]
    pairs += [("item", f"yt:{video_id}:{title}") for video_id, title in playlist["items"]]
    query = "&".join(f"{key}={quote(value, safe=SAFE)}" for key, value in pairs)
    return f"burrow://playlist?{query}"


def section(playlist):
    kind = "Music tile" if playlist["type"] == "music" else "Video tile"
    songs = "\n".join(
        f'      <li><a href="https://www.youtube.com/watch?v={video_id}">{html.escape(title)}</a></li>'
        for video_id, title in playlist["items"]
    )
    return f"""
  <section>
    <h2>{html.escape(playlist["name"])}</h2>
    <p class="kind">{kind} · {len(playlist["items"])} songs · from {html.escape(playlist["source"])}</p>
    <p>{html.escape(playlist["about"])}</p>
    <a class="add" href="{html.escape(link(playlist))}">Add to Burrow</a>
    <ol>
{songs}
    </ol>
  </section>"""


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Burrow — Playlists</title>
  <style>
    body {{ font-family: -apple-system, system-ui, sans-serif; max-width: 640px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #222; }}
    section {{ border-top: 1px solid #ddd; padding-top: 8px; margin-top: 28px; }}
    .kind {{ color: #666; font-size: 0.9em; margin: -8px 0 8px; }}
    a.add {{ display: inline-block; background: #67879f; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 12px; font-weight: 600; }}
    ol {{ color: #444; }}
    .note {{ color: #666; font-size: 0.9em; }}
    @media (prefers-color-scheme: dark) {{
      body {{ background: #111; color: #ddd; }} a {{ color: #8ab4ff; }}
      section {{ border-color: #333; }} .kind, .note {{ color: #999; }} ol {{ color: #bbb; }}
      a.add {{ background: #92adc4; color: #111; }}
    }}
  </style>
</head>
<body>
  <h1>Burrow — Playlists</h1>

  <p>Ready-made playlists for Burrow. Open this page on the iPhone or iPad that has Burrow and tap <em>Add to Burrow</em>. Burrow asks for the grown-up's year of birth, shows you the playlist, and adds it as a tile only once you choose a profile and tap <em>Add tile</em>.</p>

  <p class="note">The free version adds the first three songs of a playlist; the unlock adds them all. Every song plays from YouTube, so it needs an internet connection and keeps working only for as long as YouTube allows it.</p>
{sections}

  <p class="note">Burrow is not affiliated with Kinderpretpark Julianatoren, the Efteling or Disney. These playlists only point to videos on their own official YouTube channels; the songs belong to them. Tap a song to see it on YouTube first.</p>

  <p><a href="support.html">Support</a> · <a href="privacy.html">Privacy</a></p>
</body>
</html>
"""


def main():
    out = PAGE.format(sections="\n".join(section(p) for p in PLAYLISTS))
    with open(sys.argv[1], "w", encoding="utf-8") as f:
        f.write(out)


if __name__ == "__main__":
    main()
