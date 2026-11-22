#!/usr/bin/env python3
"""Writes website/playlists.html: ready-made playlists a parent can add to
Burrow with one tap, with a table at the top as the overview.

Usage: Scripts/make_playlists_page.py website/playlists.html

Each playlist becomes a burrow://playlist link in the same format the app's
"Share as link" writes (see Burrow/Services/PlaylistLink.swift). Only use
uploads from the rights holder's own channel, and check that each video still
exists and allows embedding before republishing: YouTube's oEmbed endpoint
(https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=<id>)
answers 401 for a video that may not be embedded and 404 for one that is gone,
and names the channel otherwise.
"""
import html
import re
import sys
from urllib.parse import quote

PLAYLISTS = [
    {
        "name": "Efteling",
        "type": "music",
        "ages": "All ages",
        "owner": "the Efteling",
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
        "name": "Efteling rides",
        "type": "video",
        "ages": "3+",
        "owner": "the Efteling",
        "about": "A walk through the Fairy Tale Forest and a seat on the gentle "
                 "rides, filmed by the Efteling itself. No big roller coasters.",
        "source": "the Efteling's YouTube channel",
        "items": [
            ("40ppGVR5nZQ", "Sprookjesbos"),
            ("ZYvTqDzZcPk", "Droomvlucht"),
            ("VRHWrWhC6qo", "Carnaval Festival"),
            ("mXdXR82IkvQ", "Fata Morgana"),
            ("95PBLcebK0M", "Symbolica"),
            ("NkGXAFAe3ig", "Max & Moritz"),
        ],
    },
    {
        "name": "Jokie & Jet",
        "type": "video",
        "ages": "1–5",
        "owner": "the Efteling",
        "about": "Short songs and stories with Jokie and Jet, the Efteling's "
                 "little ones, from the Efteling Kids channel.",
        "source": "Efteling Kids on YouTube",
        "items": [
            ("zmq1x18-UG0", "Spelen in de speeltuin"),
            ("LWCkOnZzsqE", "De dierendans"),
            ("3N4qBCkeB4o", "Hieperdepiep"),
            ("67v7rBPr-MI", "Pretpark"),
            ("3vcRyGk2tjc", "Brandweer"),
            ("Z_0QoWbEJGA", "Duiken"),
            ("piO5cqtfqTI", "Kermis"),
        ],
    },
    {
        "name": "Julianatoren",
        "type": "video",
        "ages": "2–6",
        "owner": "Kinderpretpark Julianatoren",
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
        "name": "Studio 100 hits",
        "type": "video",
        "ages": "3–8",
        "owner": "Studio 100",
        "about": "The big sing-alongs: K3, Kabouter Plop, Samson & Gert, Piet "
                 "Piraat, Mega Mindy and Maya, each from its own official channel.",
        "source": "Studio 100's official YouTube channels",
        "items": [
            ("ZRMTC9Tzj2c", "K3 – Alle Kleuren"),
            ("6fMwrdWmExg", "K3 – 10.000 luchtballonnen"),
            ("_9ZWV6SjzO0", "K3 – Waterval"),
            ("qhBVYe5nB54", "Kabouter Plop – Kabouterdans"),
            ("xZEMDZSBkZg", "Kabouter Plop – De Regendans"),
            ("O_mjKdxkQZk", "Samson & Gert – Wij gaan vliegen"),
            ("eVMaFXbYrMk", "Piet Piraat – Wij zijn zeepiraten"),
            ("1vVTJbH7HMM", "Mega Mindy – Mega Mindy Tijd"),
            ("rOu7kt5b76M", "Maya de Bij – Daar heb je Maya de Bij"),
        ],
    },
    {
        "name": "Bumba",
        "type": "video",
        "ages": "1–4",
        "owner": "Studio 100",
        "about": "Dance, clap and stamp along with Bumba the clown, and one to "
                 "end the day with.",
        "source": "Bumba NL on YouTube",
        "items": [
            ("CKslYf-VVho", "Zwaai, spring, stamp, klap"),
            ("abfLZW5rqDQ", "De Bumba Dans"),
            ("2YAbykYBe74", "Bumba trein"),
            ("SnCnDmW08r8", "De Knuffeldans"),
            ("5fAZ6iNX0l8", "Het Orkest"),
            ("DXFucH5wzOs", "De Bumba stopdans"),
            ("pbV98FF1j-M", "Bumba naar bed"),
        ],
    },
    {
        "name": "Maya de Bij",
        "type": "video",
        "ages": "2–6",
        "owner": "Studio 100",
        "about": "Songs from Maya the Bee and her friends, with the Maya Dans "
                 "step by step.",
        "source": "Maya de Bij and Studio 100 on YouTube",
        "items": [
            ("rOu7kt5b76M", "Daar heb je Maya de Bij"),
            ("DodTU2nJIOg", "Ik heb een vriend"),
            ("GKl9ZcG6eQQ", "De Maya Dans"),
            ("JHAUeUbo5oM", "Poesje Mauw"),
            ("xjgDiw93tIY", "We stegen met een zucht"),
            ("gifUNhTViXA", "Lang zal ze leven"),
        ],
    },
    {
        "name": "nijntje",
        "type": "video",
        "ages": "1–4",
        "owner": "Mercis (nijntje)",
        "about": "Gentle songs with Miffy and Boris Bear, from nijntje's own "
                 "channel.",
        "source": "nijntje on YouTube",
        "items": [
            ("20J8DUJMgA4", "Dans mee met nijntje"),
            ("KSzKwXPb82c", "nijntje liedje"),
            ("FmyZFwJdnzk", "De seizoenen"),
            ("zXp5wXoZECs", "Zeg ken jij Boris Beer?"),
            ("hhYiTVmZh_8", "Mijn liefste hond"),
        ],
    },
    {
        "name": "Woezel & Pip",
        "type": "video",
        "ages": "1–5",
        "owner": "Woezel & Pip",
        "about": "Songs about friendship from the Tovertuin, ending with a "
                 "lullaby.",
        "source": "Woezel & Pip TV on YouTube",
        "items": [
            ("FmnnSZrB9lY", "Allerbeste vriendjes"),
            ("xKkAwMkE6Fs", "Vriendjesclublied"),
            ("GbkLA6nDIFA", "Het Vriendjeslied"),
            ("IPWVrWyoHP0", "Tovertuindans"),
            ("bdoqrqD3esw", "Liedje van geluk"),
            ("GzPb9-Z0hqU", "Land van je ogen dicht"),
        ],
    },
    {
        "name": "Juf Roos",
        "type": "video",
        "ages": "1–4",
        "owner": "Juf Roos",
        "about": "The classic Dutch nursery rhymes, sung slowly and clearly by "
                 "Juf Roos. Short, so good for a few minutes at a time.",
        "source": "Juf Roos on YouTube",
        "items": [
            ("hI8IPM76vrw", "In de Maneschijn"),
            ("vzvbBIt_r6c", "Ik zag twee beren broodjes smeren"),
            ("YdfbFy9uVrU", "Het regent, het regent"),
            ("oRWWJaBHYoY", "Poesje Mauw"),
            ("JuqCZxmzJDQ", "Hop paardje hop"),
            ("zy1coEWIGSw", "Zo gaat de molen"),
            ("t1y0H2hoTvQ", "Helikopter"),
            ("o-rrtNC0mSo", "Kleurenlied"),
            ("LfSjL_YrTrA", "Hokey Pokey"),
        ],
    },
    {
        "name": "Kinderen voor Kinderen",
        "type": "video",
        "ages": "5+",
        "owner": "Kinderen voor Kinderen",
        "about": "The best-known songs of the children's choir, for the older "
                 "ones who want to dance.",
        "source": "Kinderen voor Kinderen on YouTube",
        "items": [
            ("N2Rl9hEJVKE", "Hupsakee"),
            ("fAElk6S2gZg", "Raar maar waar"),
            ("xtgl2E7BVPg", "Haai-alarm!"),
            ("cPDKS45RhkA", "Red de bij"),
            ("Agy0kqdMBDE", "Reis mee!"),
            ("iYHe2V-zwkQ", "Baila bailalaa"),
            ("gvHpI_6Bq_4", "Lekker eigenwijs"),
        ],
    },
    {
        "name": "Disney",
        "type": "video",
        "ages": "4+",
        "owner": "Disney",
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


def anchor(playlist):
    return re.sub(r"[^a-z0-9]+", "-", playlist["name"].lower()).strip("-")


def kind(playlist):
    return "Music" if playlist["type"] == "music" else "Video"


def count(playlist):
    noun = "songs" if playlist["type"] == "music" else "videos"
    return f"{len(playlist['items'])} {noun}"


def row(playlist):
    return f"""      <tr>
        <td><a href="#{anchor(playlist)}">{html.escape(playlist["name"])}</a><span class="sub">{kind(playlist)} tile</span></td>
        <td>{len(playlist["items"])}</td>
        <td>{html.escape(playlist["ages"])}</td>
        <td><a class="add small" href="{html.escape(link(playlist))}">Add</a></td>
      </tr>"""


def section(playlist):
    songs = "\n".join(
        f'      <li><a href="https://www.youtube.com/watch?v={video_id}">{html.escape(title)}</a></li>'
        for video_id, title in playlist["items"]
    )
    return f"""
  <section id="{anchor(playlist)}">
    <h2>{html.escape(playlist["name"])}</h2>
    <p class="kind">{kind(playlist)} tile · {count(playlist)} · ages {html.escape(playlist["ages"])} · from {html.escape(playlist["source"])}</p>
    <p>{html.escape(playlist["about"])}</p>
    <a class="add" href="{html.escape(link(playlist))}">Add to Burrow</a>
    <ol>
{songs}
    </ol>
  </section>"""


def owners():
    names = list(dict.fromkeys(p["owner"] for p in PLAYLISTS))
    return ", ".join(names[:-1]) + " or " + names[-1]


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Burrow — Playlists</title>
  <style>
    body {{ font-family: -apple-system, system-ui, sans-serif; max-width: 680px; margin: 40px auto; padding: 0 16px; line-height: 1.6; color: #222; }}
    section {{ border-top: 1px solid #ddd; padding-top: 8px; margin-top: 28px; scroll-margin-top: 12px; }}
    .kind {{ color: #666; font-size: 0.9em; margin: -8px 0 8px; }}
    a.add {{ display: inline-block; background: #67879f; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 12px; font-weight: 600; }}
    a.add.small {{ padding: 4px 14px; border-radius: 10px; font-size: 0.9em; }}
    table {{ width: 100%; border-collapse: collapse; margin: 16px 0 8px; font-variant-numeric: tabular-nums; }}
    th, td {{ text-align: left; padding: 8px 6px; border-bottom: 1px solid #e4e4e4; vertical-align: middle; }}
    th {{ font-size: 0.8em; text-transform: uppercase; letter-spacing: 0.04em; color: #666; font-weight: 600; }}
    td:nth-child(2), th:nth-child(2) {{ text-align: right; }}
    td:nth-child(3) {{ white-space: nowrap; }}
    .sub {{ display: block; color: #666; font-size: 0.8em; }}
    td:last-child, th:last-child {{ text-align: right; }}
    td:first-child a {{ font-weight: 600; text-decoration: none; }}
    ol {{ color: #444; }}
    .note {{ color: #666; font-size: 0.9em; }}
    @media (prefers-color-scheme: dark) {{
      body {{ background: #111; color: #ddd; }} a {{ color: #8ab4ff; }}
      section {{ border-color: #333; }} .kind, .note, th, .sub {{ color: #999; }} ol {{ color: #bbb; }}
      th, td {{ border-color: #2a2a2a; }}
      a.add {{ background: #92adc4; color: #111; }}
    }}
  </style>
</head>
<body>
  <h1>Burrow — Playlists</h1>

  <p>Ready-made playlists for Burrow. Open this page on the iPhone or iPad that has Burrow and tap <em>Add</em>. Burrow asks for the grown-up's year of birth, shows you the playlist, and adds it as a tile only once you choose a profile and tap <em>Add tile</em>.</p>

  <table>
    <thead>
      <tr><th>Playlist</th><th>Items</th><th>Ages</th><th></th></tr>
    </thead>
    <tbody>
{rows}
    </tbody>
  </table>

  <p class="note">The free version adds the first three items of a playlist; the unlock adds them all. Everything plays from YouTube, so it needs an internet connection and keeps working only for as long as YouTube allows it. The ages are a rough guide.</p>
{sections}

  <p class="note">Burrow is not affiliated with {owners}. These playlists only point to videos on their own official YouTube channels; the songs and videos belong to them. Tap a title to see it on YouTube first.</p>

  <p><a href="support.html">Support</a> · <a href="privacy.html">Privacy</a></p>
</body>
</html>
"""


def main():
    out = PAGE.format(
        rows="\n".join(row(p) for p in PLAYLISTS),
        sections="\n".join(section(p) for p in PLAYLISTS),
        owners=html.escape(owners()),
    )
    with open(sys.argv[1], "w", encoding="utf-8") as f:
        f.write(out)


if __name__ == "__main__":
    main()
