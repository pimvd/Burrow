#!/usr/bin/env python3
"""Writes the website's playlist pages: one page of ready-made playlists per
language, each with a table at the top as the overview and a row of buttons
to the other languages.

Usage: Scripts/make_playlists_page.py website

The playlists live in Scripts/playlists/<language>.json. Dutch keeps the
original address, playlists.html, so links already shared keep working; the
others are playlists-<language>.html.

Each playlist becomes a burrow://playlist link in the same format the app's
"Share as link" writes (see Burrow/Services/PlaylistLink.swift). Only use
uploads from the rights holder's own channel, and check that each video still
exists and allows embedding before republishing: YouTube's oEmbed endpoint
(https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=<id>)
answers 401 for a video that may not be embedded and 404 for one that is gone,
and names the channel otherwise. Scripts/check_playlists.py does that for
every file.
"""
import html
import json
import os
import re
import sys
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))

# The order of the language buttons. Each page names its language in that
# language, so a parent finds their own whichever page they land on.
LANGUAGES = ["en", "nl", "de", "fr", "es", "it"]
NATIVE = {
    "en": "English", "nl": "Nederlands", "de": "Deutsch",
    "fr": "Français", "es": "Español", "it": "Italiano",
}


def filename(lang):
    return "playlists.html" if lang == "nl" else f"playlists-{lang}.html"


# The words on each page. The button names in the intro (`add`, `add_tile`)
# must match the app's own String Catalog for that language. Burrow has no
# Italian translation, so iOS shows it in English, and the Italian page names
# the English button.
TEXT = {
    "en": {
        "title": "Playlists",
        "intro": "Ready-made playlists for Burrow, in English. Open this page on the iPhone or iPad that has Burrow and tap <em>Add</em>. Burrow asks for the grown-up's year of birth, shows you the playlist, and adds it as a tile, with its own picture, only once you choose one or more profiles and tap <em>Add tile</em>.",
        "other": "Playlists in other languages",
        "playlist": "Playlist", "items": "Items", "ages": "Ages",
        "add": "Add", "add_big": "Add to Burrow",
        "music": "Music tile", "video": "Video tile", "songs": "songs", "videos": "videos",
        "ages_label": "ages", "from": "from",
        "note": "The free version adds the first three items of a playlist; the unlock adds them all. Everything plays from YouTube, so it needs an internet connection and keeps working only for as long as YouTube allows it. The ages are a rough guide.",
        "disclaimer": "Burrow is not affiliated with {owners}. These playlists only point to videos on their own official YouTube channels; the songs and videos belong to them. Tap a title to see it on YouTube first.",
        "or": "or", "home": "Home", "support": "Support", "privacy": "Privacy",
    },
    "nl": {
        "title": "Playlists",
        "intro": "Kant-en-klare playlists voor Burrow, in het Nederlands. Open deze pagina op de iPhone of iPad met Burrow en tik op <em>Voeg toe</em>. Burrow vraagt naar het geboortejaar van de volwassene, laat de playlist zien en voegt hem pas als tegel toe, met een eigen plaatje, als je een of meer profielen kiest en op <em>Tegel toevoegen</em> tikt.",
        "other": "Playlists in andere talen",
        "playlist": "Playlist", "items": "Items", "ages": "Leeftijd",
        "add": "Voeg toe", "add_big": "Voeg toe aan Burrow",
        "music": "Muziektegel", "video": "Videotegel", "songs": "liedjes", "videos": "video's",
        "ages_label": "leeftijd", "from": "van",
        "note": "De gratis versie voegt de eerste drie items van een playlist toe; met de ontgrendeling komen ze er allemaal in. Alles speelt af via YouTube, dus er is internet nodig en het werkt zolang YouTube dat toestaat. De leeftijden zijn een ruwe richtlijn.",
        "disclaimer": "Burrow is niet verbonden aan {owners}. Deze playlists verwijzen alleen naar video's op hun eigen officiële YouTube-kanalen; de liedjes en video's zijn van hen. Tik op een titel om hem eerst op YouTube te bekijken.",
        "or": "of", "home": "Home", "support": "Support", "privacy": "Privacy",
    },
    "de": {
        "title": "Playlists",
        "intro": "Fertige Playlists für Burrow, auf Deutsch. Öffne diese Seite auf dem iPhone oder iPad mit Burrow und tippe auf <em>Hinzufügen</em>. Burrow fragt nach dem Geburtsjahr eines Erwachsenen, zeigt dir die Playlist und fügt sie erst als Kachel mit eigenem Bild hinzu, wenn du ein oder mehrere Profile wählst und auf <em>Kachel hinzufügen</em> tippst.",
        "other": "Playlists in anderen Sprachen",
        "playlist": "Playlist", "items": "Titel", "ages": "Alter",
        "add": "Hinzufügen", "add_big": "Zu Burrow hinzufügen",
        "music": "Musikkachel", "video": "Videokachel", "songs": "Lieder", "videos": "Videos",
        "ages_label": "Alter", "from": "von",
        "note": "Die kostenlose Version fügt die ersten drei Titel einer Playlist hinzu, die Freischaltung alle. Alles läuft über YouTube, braucht also eine Internetverbindung und funktioniert nur so lange, wie YouTube es erlaubt. Die Altersangaben sind ein grober Richtwert.",
        "disclaimer": "Burrow steht in keiner Verbindung zu {owners}. Diese Playlists verweisen nur auf Videos auf deren eigenen offiziellen YouTube-Kanälen; die Lieder und Videos gehören ihnen. Tippe auf einen Titel, um ihn zuerst auf YouTube anzusehen.",
        "or": "oder", "home": "Startseite", "support": "Hilfe", "privacy": "Datenschutz",
    },
    "fr": {
        "title": "Playlists",
        "intro": "Des playlists toutes prêtes pour Burrow, en français. Ouvrez cette page sur l'iPhone ou l'iPad où Burrow est installé et touchez <em>Ajouter</em>. Burrow demande l'année de naissance de l'adulte, vous montre la playlist et ne l'ajoute comme tuile, avec sa propre image, qu'une fois que vous avez choisi un ou plusieurs profils et touché <em>Ajouter la tuile</em>.",
        "other": "Playlists dans d'autres langues",
        "playlist": "Playlist", "items": "Titres", "ages": "Âge",
        "add": "Ajouter", "add_big": "Ajouter à Burrow",
        "music": "Tuile musique", "video": "Tuile vidéo", "songs": "chansons", "videos": "vidéos",
        "ages_label": "âge", "from": "de",
        "note": "La version gratuite ajoute les trois premiers titres d'une playlist ; le déblocage les ajoute tous. Tout est lu depuis YouTube : il faut une connexion internet, et cela fonctionne tant que YouTube le permet. Les âges sont donnés à titre indicatif.",
        "disclaimer": "Burrow n'est pas affilié à {owners}. Ces playlists renvoient uniquement vers des vidéos de leurs propres chaînes YouTube officielles ; les chansons et les vidéos leur appartiennent. Touchez un titre pour le voir d'abord sur YouTube.",
        "or": "ou", "home": "Accueil", "support": "Assistance", "privacy": "Confidentialité",
    },
    "es": {
        "title": "Playlists",
        "intro": "Listas listas para usar en Burrow, en español. Abre esta página en el iPhone o iPad que tiene Burrow y toca <em>Añadir</em>. Burrow pide el año de nacimiento de un adulto, te muestra la lista y solo la añade como mosaico, con su propia imagen, cuando eliges uno o más perfiles y tocas <em>Añadir mosaico</em>.",
        "other": "Listas en otros idiomas",
        "playlist": "Lista", "items": "Elementos", "ages": "Edad",
        "add": "Añadir", "add_big": "Añadir a Burrow",
        "music": "Mosaico de música", "video": "Mosaico de vídeo", "songs": "canciones", "videos": "vídeos",
        "ages_label": "edad", "from": "de",
        "note": "La versión gratuita añade los tres primeros elementos de una lista; el desbloqueo los añade todos. Todo se reproduce desde YouTube, así que necesita conexión a internet y funciona mientras YouTube lo permita. Las edades son orientativas.",
        "disclaimer": "Burrow no está afiliado a {owners}. Estas listas solo enlazan a vídeos de sus propios canales oficiales de YouTube; las canciones y los vídeos son suyos. Toca un título para verlo primero en YouTube.",
        "or": "ni", "home": "Inicio", "support": "Ayuda", "privacy": "Privacidad",
    },
    "it": {
        "title": "Playlist",
        "intro": "Playlist pronte per Burrow, in italiano. Apri questa pagina sull'iPhone o sull'iPad con Burrow e tocca <em>Aggiungi</em>. Burrow chiede l'anno di nascita di un adulto, ti mostra la playlist e la aggiunge come riquadro, con la sua immagine, solo dopo che hai scelto uno o più profili e toccato <em>Add tile</em>. Burrow non è ancora tradotto in italiano, quindi l'app appare in inglese.",
        "other": "Playlist in altre lingue",
        "playlist": "Playlist", "items": "Brani", "ages": "Età",
        "add": "Aggiungi", "add_big": "Aggiungi a Burrow",
        "music": "Riquadro musica", "video": "Riquadro video", "songs": "canzoni", "videos": "video",
        "ages_label": "età", "from": "da",
        "note": "La versione gratuita aggiunge i primi tre elementi di una playlist; lo sblocco li aggiunge tutti. Tutto viene riprodotto da YouTube, quindi serve una connessione a internet e funziona finché YouTube lo consente. Le età sono indicative.",
        "disclaimer": "Burrow non è affiliato a {owners}. Queste playlist rimandano solo a video dei loro canali YouTube ufficiali; le canzoni e i video appartengono a loro. Tocca un titolo per vederlo prima su YouTube.",
        "or": "o", "home": "Home", "support": "Assistenza", "privacy": "Privacy",
    },
}

# The icons a parent can pick in the app (TileArtwork.icons); the app falls
# back to one of these on a colour theme (ThemePalette) when the playlist's
# picture cannot be downloaded.
ICONS = {
    "music.note", "guitars.fill", "pianokeys", "film", "play.rectangle.fill",
    "book.fill", "car.fill", "airplane", "tram.fill", "pawprint.fill",
    "leaf.fill", "sun.max.fill", "moon.stars.fill", "star.fill", "balloon.fill",
    "teddybear.fill", "soccerball", "paintpalette.fill", "crown.fill",
    "sparkles", "wand.and.stars", "balloon.2.fill", "party.popper.fill",
    "figure.dance", "music.mic", "hare.fill", "dog.fill", "ladybug.fill",
    "heart.fill",
}

# ThemePalette's tints, for the swatch on this page.
COLOURS = {
    "sage": "#67879f", "clay": "#bd8773", "moss": "#7b9679",
    "lavender": "#988caf", "sand": "#bfaf87", "slate": "#78828e",
}

# Same set PlaylistLink.swift leaves unescaped: letters, digits, -._~ and the
# colon that separates an item's parts.
SAFE = "-._~:"
VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")


def load(lang):
    with open(os.path.join(HERE, "playlists", f"{lang}.json"), encoding="utf-8") as f:
        playlists = json.load(f)
    for p in playlists:
        where = f"{lang}: {p['name']}"
        assert p["type"] in ("music", "video"), where
        assert p["icon"] in ICONS, f"{where}: unknown icon {p['icon']}"
        assert p["color"] in COLOURS, f"{where}: unknown colour {p['color']}"
        assert p["items"], where
        assert all(VIDEO_ID.match(v) for v, _ in p["items"]), where
        # The official picture: the thumbnail of one of the playlist's own
        # videos. The app downloads it when the playlist is added and crops
        # it square; the icon is only the fallback.
        assert p["image"] in [v for v, _ in p["items"]], f"{where}: image is not one of its videos"
    return playlists


def image(playlist):
    return f"https://i.ytimg.com/vi/{playlist['image']}/hq720.jpg"


def link(playlist):
    pairs = [("name", playlist["name"]), ("type", playlist["type"]), ("icon", playlist["icon"]),
             ("color", playlist["color"]), ("image", image(playlist))]
    pairs += [("item", f"yt:{video_id}:{title}") for video_id, title in playlist["items"]]
    query = "&".join(f"{key}={quote(value, safe=SAFE)}" for key, value in pairs)
    return f"burrow://playlist?{query}"


def anchor(playlist):
    return re.sub(r"[^a-z0-9]+", "-", playlist["name"].lower()).strip("-")


def swatch(playlist, size=""):
    return (f'<img class="art{size}" src="{image(playlist)}" alt="" loading="lazy" '
            f'style="background:{COLOURS[playlist["color"]]}">')


def row(playlist, t):
    return f"""      <tr>
        <td><div class="name">{swatch(playlist)}<span><a href="#{anchor(playlist)}">{html.escape(playlist["name"])}</a><span class="sub">{t[playlist["type"]]}</span></span></div></td>
        <td>{len(playlist["items"])}</td>
        <td>{html.escape(playlist["ages"])}</td>
        <td><a class="add small" href="{html.escape(link(playlist))}">{t["add"]}</a></td>
      </tr>"""


def section(playlist, t):
    songs = "\n".join(
        f'      <li><a href="https://www.youtube.com/watch?v={video_id}">{html.escape(title)}</a></li>'
        for video_id, title in playlist["items"]
    )
    noun = t["songs"] if playlist["type"] == "music" else t["videos"]
    source = f'{t["from"]} {playlist["source"]}'
    # Spanish contracts "de el" to "del".
    source = re.sub(r"^de el ", "del ", source)
    ages = playlist["ages"]
    ages = f"{t['ages_label']} {ages}" if re.search(r"\d", ages) else ages
    return f"""
  <section id="{anchor(playlist)}">
    <h2>{swatch(playlist, " big")}{html.escape(playlist["name"])}</h2>
    <p class="kind">{t[playlist["type"]]} · {len(playlist["items"])} {noun} · {html.escape(ages)} · {html.escape(source)}</p>
    <p>{html.escape(playlist["about"])}</p>
    <a class="add" href="{html.escape(link(playlist))}">{t["add_big"]}</a>
    <ol>
{songs}
    </ol>
  </section>"""


def owners(playlists, t):
    names = list(dict.fromkeys(p["owner"] for p in playlists))
    if len(names) == 1:
        return names[0]
    return ", ".join(names[:-1]) + f" {t['or']} " + names[-1]


def language_buttons(current):
    buttons = []
    for lang in LANGUAGES:
        if lang == current:
            buttons.append(f'<a class="lang" href="{filename(lang)}" lang="{lang}" aria-current="page">{NATIVE[lang]}</a>')
        else:
            buttons.append(f'<a class="lang" href="{filename(lang)}" lang="{lang}" hreflang="{lang}">{NATIVE[lang]}</a>')
    return "\n    ".join(buttons)


def alternates():
    return "\n".join(f'  <link rel="alternate" hreflang="{lang}" href="{filename(lang)}">' for lang in LANGUAGES)


PAGE = """<!DOCTYPE html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="apple-itunes-app" content="app-id=6837952478">
  <title>Burrow — {title} ({native})</title>
{alternates}
  <link rel="icon" href="icon.png">
  <style>
    body {{ font-family: -apple-system, system-ui, sans-serif; max-width: 680px; margin: 40px auto; padding: 0 16px; line-height: 1.6; color: #222; }}
    section {{ border-top: 1px solid #ddd; padding-top: 8px; margin-top: 28px; scroll-margin-top: 12px; }}
    .kind {{ color: #666; font-size: 0.9em; margin: -8px 0 8px; }}
    a.add {{ display: inline-block; background: #67879f; color: #fff; text-decoration: none; padding: 10px 20px; border-radius: 12px; font-weight: 600; }}
    a.add.small {{ padding: 4px 14px; border-radius: 10px; font-size: 0.9em; }}
    nav.langs {{ display: flex; flex-wrap: wrap; gap: 8px; margin: 8px 0 20px; }}
    a.lang {{ display: inline-block; padding: 6px 14px; border-radius: 999px; border: 1.5px solid #67879f; color: #4c6a80; text-decoration: none; font-weight: 600; font-size: 0.95em; }}
    a.lang[aria-current] {{ background: #67879f; color: #fff; }}
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
    .art {{ width: 44px; height: 44px; border-radius: 10px; object-fit: cover; flex: none; }}
    .art.big {{ width: 96px; height: 96px; border-radius: 20px; margin-right: 14px; vertical-align: middle; }}
    .name {{ display: flex; align-items: center; gap: 10px; }}
    @media (max-width: 520px) {{
      th:nth-child(2), td:nth-child(2) {{ display: none; }}
      td:nth-child(3) {{ white-space: normal; }}
      th, td {{ padding: 8px 4px; }}
      a.add.small {{ padding: 4px 10px; }}
      .name {{ gap: 8px; }}
    }}
    @media (prefers-color-scheme: dark) {{
      body {{ background: #111; color: #ddd; }} a {{ color: #8ab4ff; }}
      section {{ border-color: #333; }} .kind, .note, th, .sub {{ color: #999; }} ol {{ color: #bbb; }}
      th, td {{ border-color: #2a2a2a; }}
      a.add {{ background: #92adc4; color: #111; }}
      a.lang {{ border-color: #92adc4; color: #92adc4; }}
      a.lang[aria-current] {{ background: #92adc4; color: #111; }}
    }}
  </style>
</head>
<body>
  <h1>Burrow — {title}</h1>

  <nav class="langs" aria-label="{other}">
    {buttons}
  </nav>

  <p>{intro}</p>

  <table>
    <thead>
      <tr><th>{th_playlist}</th><th>{th_items}</th><th>{th_ages}</th><th></th></tr>
    </thead>
    <tbody>
{rows}
    </tbody>
  </table>

  <p class="note">{note}</p>
{sections}

  <p class="note">{disclaimer}</p>

  <p><a href="index.html">{home}</a> · <a href="support.html">{support}</a> · <a href="privacy.html">{privacy}</a></p>
</body>
</html>
"""


def page(lang):
    t = TEXT[lang]
    playlists = load(lang)
    return PAGE.format(
        lang=lang,
        title=t["title"],
        native=NATIVE[lang],
        alternates=alternates(),
        other=t["other"],
        buttons=language_buttons(lang),
        intro=t["intro"],
        th_playlist=t["playlist"], th_items=t["items"], th_ages=t["ages"],
        rows="\n".join(row(p, t) for p in playlists),
        note=t["note"],
        sections="\n".join(section(p, t) for p in playlists),
        disclaimer=t["disclaimer"].format(owners=html.escape(owners(playlists, t))),
        home=t["home"], support=t["support"], privacy=t["privacy"],
    )


def main():
    out_dir = sys.argv[1]
    for lang in LANGUAGES:
        with open(os.path.join(out_dir, filename(lang)), "w", encoding="utf-8") as f:
            f.write(page(lang))


if __name__ == "__main__":
    main()
