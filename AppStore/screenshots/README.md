# Screenshots

Taken by the **Screenshots** workflow, never by hand: it builds the app for the
simulator and runs `Scripts/screenshots.sh`, which launches it once per scene
with `-screenshotScene` (made-up children and tiles in memory, see
`Burrow/App/ScreenshotMode.swift`) and `-AppleLanguages` for each store
language. The pictures are committed here as `<locale>/<device>-<nn>-<scene>.png`.

| Device | Size | Simulator |
| --- | --- | --- |
| `iphone` | 1320 × 2868 (6.9") | newest iPhone Pro Max |
| `ipad` | 2064 × 2752 (13") | newest iPad Pro 13-inch |

The release workflow hands them to `fastlane deliver`, which tells the devices
apart by size. The website shows the English iPhone ones.

Scenes, in order: the profile picker, the Music tab, the Video tab, the Games
tab, a game, the parent's tile list, and the statistics.
