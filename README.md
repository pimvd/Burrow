# Kidtopia

A privacy-first, offline-first iOS app that lets a parent build large, tappable
tiles of music or video for their children. No ads, no subscriptions, no
tracking — one optional in-app purchase unlocks the limits.

- **Platform:** iOS 17+, iPhone and iPad, portrait and landscape
- **Bundle identifier:** `com.pvd.kidtopia`
- **Stack:** SwiftUI, SwiftData (+ CloudKit), Swift Charts, StoreKit 2, MusicKit,
  AVFoundation, WebKit

## Opening the project

```sh
open Kidtopia.xcodeproj
```

The only third-party dependency is
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation), resolved through
Swift Package Manager when the project is first opened.

Debug builds use `Config/Kidtopia.storekit` so the purchase flow can be tried
without App Store Connect. The iCloud entitlement in
`Config/Kidtopia.entitlements` points at `iCloud.com.pvd.kidtopia`; replace the
container identifier and development team with your own before running on a
device.

## Layout

```
Kidtopia/
  App/          Entry point, navigation router, parental session state
  Models/       SwiftData models, versioned schema, container factory
  Design/       Colour palette, avatars, age-driven layout scale, calm styling
  Services/     Playback, store, statistics, export/import, trash, notifications
  ViewModels/   @Observable view models
  Views/
    Child/      Profile picker, Music and Video tabs, tile grid, now playing
    Parent/     Everything behind the birth-year gate
    Common/     Shared small views
  Resources/    Asset catalog and the String Catalog
Config/         Info.plist, entitlements, StoreKit configuration
```

## How the pieces fit together

**Tiles are single-type.** A tile is either a music playlist (local audio and
Apple Music) or a video playlist (local video and YouTube). The category is
fixed at creation; `Tile.canAdd(sourceType:)` enforces it on every path,
including import.

**Everything a parent can change sits behind the gate.** `ParentalGateView` asks
for a birth year and accepts `1900 ... currentYear - 16`. Every failure shows the
same message, so a child cannot learn the rule by trying. The unlock lasts until
the parent leaves the parent area or the app is backgrounded.

**The child interface is deliberately quiet.** Muted palettes, no sound effects,
one `easeInOut` animation shared through `CalmStyle`. `AgeLayoutScale` turns a
profile's age (2–12) into tile size, whether captions appear and whether
playback shows transport buttons or expects a swipe.

**Playback never shows a playlist.** `MediaPlaybackService` owns the play order
(honouring shuffle and loop), drives `AVQueuePlayer`, MusicKit and the YouTube
embed, and reports failures upward. A broken YouTube link is skipped silently
for the child while the reason is stored on the media item and badged in the
parent list. Items always start at 0:00; only *which* item was playing is
remembered per tile.

**Statistics come from two kinds of rows.** `UsageRecorder` writes an *open
marker* (no media item, zero duration) each time a tile is opened, and a *play
row* per entry with its real seconds. Because the two never overlap,
`StatisticsService` can sum durations and count openings without double
counting.

**Deleting is reversible for 14 days.** `TrashService` soft-deletes tiles and
purges expired ones on launch, taking their media files, their usage rows and
any sharing references with them.

**CloudKit conflicts are surfaced, not merged silently.** Every model carries a
`lastModified` stamp. Editors snapshot it when they open and compare on save; if
another device changed the record in the meantime the parent chooses between
keeping their own version and keeping the other one.

## Notes on the data model

The models follow CloudKit's requirements for a mirrored store: every property
has a default value or is optional, relationships are optional and have an
inverse, and there are no uniqueness constraints. Two deliberate naming choices:

- `Tile.isTrashed` rather than `isDeleted`, because `PersistentModel` already
  vends an `isDeleted` property.
- `Tile.categoryRawValue` / `MediaItem.typeRawValue` are stored as strings with
  typed `category` / `type` accessors, keeping the CloudKit schema plain.

## Building from the command line

```sh
xcodebuild build \
  -project Kidtopia.xcodeproj \
  -scheme Kidtopia \
  -destination 'generic/platform=iOS Simulator'
```

The same command runs in CI on every push (`.github/workflows/build.yml`).

## Localization

`Kidtopia/Resources/Localizable.xcstrings` holds every user-facing string in
English (source), Dutch, German, French and Spanish. Adding a language means
adding it to the catalog and to `knownRegions` in the project file; nothing in
the code changes.
