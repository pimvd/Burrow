#!/usr/bin/env python3
"""Turns the store text into fastlane's layout for `fastlane deliver`.

Run: python3 Scripts/metadata_to_fastlane.py [output_dir]   (default: fastlane)

The store text has one home, APP_STORE_METADATA.md, with one section per
language; the App Review notes come from APP_REVIEW_NOTES.md. This reads both,
checks every field against App Store Connect's limits, and writes
<output_dir>/metadata. Screenshots in AppStore/screenshots/<locale>/ are
copied to <output_dir>/screenshots. The output is generated; do not commit it.

With --check it only validates, which is what CI runs on every push.
"""
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
METADATA = REPO / "APP_STORE_METADATA.md"
REVIEW_NOTES = REPO / "APP_REVIEW_NOTES.md"
SCREENSHOTS = REPO / "AppStore" / "screenshots"

# Section heading in APP_STORE_METADATA.md -> App Store locale.
LOCALES = {
    "English (en-US)": "en-US",
    "German (de-DE)": "de-DE",
    "Spanish (es-ES)": "es-ES",
    "French (fr-FR)": "fr-FR",
    "Dutch (nl-NL)": "nl-NL",
}
PRIMARY = "en-US"

LIMITS = {"name": 30, "subtitle": 30, "promotional_text": 170, "description": 4000, "keywords": 100}

SHARED = {
    "privacy_url": "https://vandijkcloud.nl/burrow/privacy.html",
    "support_url": "https://vandijkcloud.nl/burrow/support.html",
    "marketing_url": "https://vandijkcloud.nl/burrow/",
}
TOP_LEVEL = {
    "copyright": "2026 Pim van Dijk",
    "primary_category": "EDUCATION",
    "secondary_category": "ENTERTAINMENT",
}


def sections(text: str) -> dict:
    """Splits the document on its `## ` headings."""
    parts = re.split(r"^## (.+)$", text, flags=re.M)
    # "English (en-US) — primary" is filed under "English (en-US)".
    return {parts[i].split(" — ")[0].strip(): parts[i + 1] for i in range(1, len(parts), 2)}


def fields(body: str) -> dict:
    """Reads the **Label** blocks of one language section."""
    body = body.split("\n---")[0]
    parts = re.split(r"^\*\*(.+?)\*\*.*$", body, flags=re.M)
    raw = {parts[i].strip(): parts[i + 1].strip() for i in range(1, len(parts), 2)}

    def code(value: str) -> str:
        match = re.match(r"`([^`]+)`", value)
        if not match:
            raise ValueError(f"expected a `value` in: {value[:40]!r}")
        return match.group(1)

    promo = " ".join(line.strip() for line in raw["Promotional text"].splitlines() if line.strip())
    return {
        "name": code(raw["App name"]),
        "subtitle": code(raw["Subtitle"]),
        "promotional_text": promo,
        "description": raw["Description"].strip(),
        "keywords": code(raw["Keywords"]),
    }


def review_notes() -> str:
    text = REVIEW_NOTES.read_text(encoding="utf-8")
    return text[text.index("# App Review Notes"):].split("\n", 1)[1].strip()


def load() -> dict:
    found = sections(METADATA.read_text(encoding="utf-8"))
    result = {}
    for heading, locale in LOCALES.items():
        if heading not in found:
            raise SystemExit(f"APP_STORE_METADATA.md has no section '## {heading}'")
        result[locale] = fields(found[heading])
    return result


def check(metadata: dict) -> list:
    problems = []
    for locale, data in metadata.items():
        for key, limit in LIMITS.items():
            if len(data[key]) > limit:
                problems.append(f"{locale} {key}: {len(data[key])} characters, the limit is {limit}")
        if " ," in data["keywords"] or ", " in data["keywords"]:
            problems.append(f"{locale} keywords: no spaces around commas, they count against the limit")
        for word in ("YouTube", "Spotify", "Toniebox"):
            if word.lower() in data["keywords"].lower() or word.lower() in data["name"].lower():
                problems.append(f"{locale}: '{word}' in the name or keywords is a trademark rejection risk")
    if len(review_notes()) > 4000:
        problems.append(f"review notes: {len(review_notes())} characters, the limit is 4000")
    return problems


def main() -> int:
    metadata = load()
    problems = check(metadata)
    for problem in problems:
        print(f"::error::{problem}")
    if problems:
        return 1
    if "--check" in sys.argv:
        print(f"Store text OK for {', '.join(metadata)}")
        return 0

    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = Path(args[0]) if args else REPO / "fastlane"
    output = root / "metadata"
    output.mkdir(parents=True, exist_ok=True)
    for key, value in TOP_LEVEL.items():
        (output / f"{key}.txt").write_text(value + "\n", encoding="utf-8")
    (output / "review_information").mkdir(exist_ok=True)
    (output / "review_information" / "notes.txt").write_text(review_notes() + "\n", encoding="utf-8")
    for locale, data in metadata.items():
        folder = output / locale
        folder.mkdir(exist_ok=True)
        for key, value in {**data, **SHARED}.items():
            (folder / f"{key}.txt").write_text(value + "\n", encoding="utf-8")
    print(f"Wrote fastlane metadata for {len(metadata)} locales to {output}")

    # A locale without screenshots of its own uses the primary locale's.
    copied = 0
    for locale in metadata:
        source = SCREENSHOTS / locale
        if not any(source.glob("*.png")):
            source = SCREENSHOTS / PRIMARY
        target = root / "screenshots" / locale
        for picture in sorted(source.glob("*.png")):
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(picture, target / picture.name)
            copied += 1
    print(f"Copied {copied} screenshots to {root / 'screenshots'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
