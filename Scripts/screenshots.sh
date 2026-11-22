#!/bin/bash
# Takes the App Store screenshots in the iOS simulator, in every store language,
# on the two screen sizes App Store Connect asks for:
#   iPhone 6.9"  1320 x 2868   (the newest "Pro Max")
#   iPad 13"     2064 x 2752   (the newest "iPad Pro 13-inch")
# Run after a Release simulator build into ./build (see screenshots.yml).
# Writes AppStore/screenshots/<locale>/<device>-<nn>-<scene>.png.
#
# Every shot starts the app cold with -screenshotScene, which the app reads as a
# setting: it opens an in-memory store of made-up children and tiles and goes
# straight to that scene (Burrow/App/ScreenshotMode.swift). -AppleLanguages
# picks the language, so the demo titles and the whole UI are translated.
set -euo pipefail

bundle=com.pvd.burrow
root=AppStore/screenshots
app=$(find build/Build/Products/Release-iphonesimulator -maxdepth 1 -name '*.app' | head -1)
[ -n "$app" ] || { echo "No simulator build in ./build"; exit 1; }

# store locale : app language
locales="en-US:en de-DE:de es-ES:es fr-FR:fr nl-NL:nl"
# Restrict with LOCALES="en-US nl-NL" when trying things out.
only=${LOCALES:-}

scenes="profiles music video games game tiles statistics"

newest() {  # newest available simulator whose name matches $1 (a regex)
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys
pattern = re.compile(sys.argv[1])
devices = json.load(sys.stdin)["devices"]
for runtime in sorted((k for k in devices if "iOS" in k), reverse=True):
    for d in sorted(devices[runtime], key=lambda d: d["name"], reverse=True):
        if pattern.search(d["name"]):
            print(d["udid"]); sys.exit()
sys.exit("No simulator matching " + sys.argv[1])
' "$1"
}

iphone=${IPHONE_UDID:-$(newest 'iPhone .*Pro Max$')}
ipad=${IPAD_UDID:-$(newest '^iPad Pro 13')}

prepare() {
  local udid=$1
  echo "Booting $udid"
  xcrun simctl boot "$udid" 2>/dev/null || true  # already booted is fine
  xcrun simctl bootstatus "$udid" -b
  echo "Setting light mode and the status bar"
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  echo "Installing the app"
  xcrun simctl install "$udid" "$app"
}

shoot() {  # device-name udid
  local name=$1 udid=$2
  for pair in $locales; do
    local locale=${pair%%:*} language=${pair##*:}
    if [ -n "$only" ] && [[ " $only " != *" $locale "* ]]; then continue; fi
    local out=$root/$locale
    mkdir -p "$out"
    rm -f "$out/$name"-*.png
    local n=0
    for scene in $scenes; do
      n=$((n + 1))
      xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
      xcrun simctl launch "$udid" "$bundle" -screenshotScene "$scene" \
        -AppleLanguages "($language)" -AppleLocale "${locale/-/_}" >/dev/null
      # The first launch on a fresh simulator is slow, and the parent scenes
      # wait a second, present and push before they are still.
      case $scene in
        tiles|statistics) wait=9 ;;
        *) wait=6 ;;
      esac
      # The iPad simulator is slower: it once still showed the profiles, or
      # their fade, after 6 seconds.
      [ "$name" = ipad ] && wait=$((wait + 6))
      [ $n -le 2 ] && wait=$((wait + 8))
      sleep $wait
      local file
      file=$(printf '%s/%s-%02d-%s.png' "$out" "$name" "$n" "$scene")
      xcrun simctl io "$udid" screenshot --type=png "$file" >/dev/null
      echo "Took $file"
    done
  done
}

# One simulator at a time: with both running, the CI runner slowed to minutes
# per command and the job ran out of time.
# Restrict with DEVICES=ipad (or iphone).
for device in "iphone:$iphone" "ipad:$ipad"; do
  name=${device%%:*} udid=${device#*:}
  if [ -n "${DEVICES:-}" ] && [[ " $DEVICES " != *" $name "* ]]; then continue; fi
  xcrun simctl shutdown all 2>/dev/null || true
  prepare "$udid"
  shoot "$name" "$udid"
done
xcrun simctl shutdown all 2>/dev/null || true

# Identical pictures mean the app never got past one screen (or a system
# prompt): fail rather than commit them.
for folder in "$root"/*/; do
  for device in iphone ipad; do
    files=("$folder"$device-*.png)
    [ -e "${files[0]}" ] || continue
    unique=$(md5 -q "${files[@]}" | sort -u | wc -l | tr -d ' ')
    if [ "$unique" -ne "${#files[@]}" ]; then
      echo "::error::$folder$device: only $unique different pictures out of ${#files[@]}; the app did not reach every scene."
      exit 1
    fi
  done
done
