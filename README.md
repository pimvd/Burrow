# Burrow

A privacy-first, offline-first iOS app that lets a parent build large, tappable
tiles of music or video for their children. No ads, no subscriptions, no
tracking — one optional in-app purchase unlocks the limits.

- **Platform:** iOS 17+, iPhone and iPad, portrait and landscape
- **Bundle identifier:** `com.pvd.burrow`
- **Stack:** SwiftUI, SwiftData (+ CloudKit), Swift Charts, StoreKit 2, MusicKit,
  AVFoundation, WebKit

## Opening the project

```sh
open Burrow.xcodeproj
```

The only third-party dependency is
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation), resolved through
Swift Package Manager when the project is first opened.

Debug builds use `Config/Burrow.storekit` so the purchase flow can be tried
without App Store Connect. The iCloud entitlement in
`Config/Burrow.entitlements` points at `iCloud.com.pvd.burrow`; replace the
container identifier and development team with your own before running on a
device.

## Layout

```
Burrow/
  App/          Entry point, navigation router, parental session state
  Models/       SwiftData models, versioned schema, container factory
  Design/       Colour palette, avatars, calm styling and layout constants
  Games/        The built-in game catalog and the games themselves
  Services/     Playback, store, statistics, export/import, trash, notifications
  ViewModels/   @Observable view models
  Views/
    Child/      Profile picker, Music, Video and Games tabs, grids, now playing
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

**Games are code, not content.** `GameCatalog` is a fixed list compiled into
the app, in the shape of `AvatarCatalog`. The only thing stored per child is
which games the parent switched on, in `ChildProfile.enabledGameIDs`. Each game
carries a stable hardcoded UUID and stands in as its own tile in usage rows, so
the statistics screens count game time without knowing games exist. Screen time
needs no special handling either: `ScreenTimeCoordinator` times the whole
session, not individual activities.

Six games ship today, listed roughly easiest first: Matching Pairs, Odd One Out
(pictures, one of which does not belong, in levels that close the gap between
the two groups), Copy the Pattern (four pads, a sequence that grows by one),
Tic Tac Toe, Four in a Row and Hangman. Each is a rules type with no SwiftUI in
it — `TicTacToeBoard`, `HangmanRound` and the rest — beside the view that draws
it, so the rules are tested directly. The two games with an opponent share
`GentleOpponent`, which takes a win when it sees one but only notices the
child's threat half the time; a perfect opponent is one a child can never beat.
No game keeps a score, and none of them can be lost in a way that ends play.

**Everything a parent can change sits behind the gate.** `ParentalGateView` asks
for a birth year and accepts `1900 ... currentYear - 16`. Every failure shows the
same message, so a child cannot learn the rule by trying. The unlock lasts until
the parent leaves the parent area or the app is backgrounded.

**The child interface is deliberately quiet.** Muted palettes, no sound effects,
one `easeInOut` animation shared through `CalmStyle`. The same file holds the
tile grid's measurements — width, corner radius, spacing, padding, title font.
Every child gets that one layout: captions always show and playback always has
its transport buttons.

**Playback never shows a playlist.** `MediaPlaybackService` owns the play order
(honouring shuffle and loop), drives `AVQueuePlayer`, MusicKit and the YouTube
embed, and reports failures upward. A broken YouTube link is skipped silently
for the child while the reason is stored on the media item and badged in the
parent list. YouTube is also the only part of the app that depends on someone
else's permission, so `YouTubeSupportNotice` holds that caveat once and the add
screen, the purchase screen and `website/support.html` all say the same thing:
it works for as long as YouTube allows it, and nothing else rests on it. Items
always start at 0:00; only *which* item was playing is remembered per tile.

**Statistics come from two kinds of rows.** `UsageRecorder` writes an *open
marker* (no media item, zero duration) each time a tile is opened, and a *play
row* per entry with its real seconds. Because the two never overlap,
`StatisticsService` can sum durations and count openings without double
counting.

**The freemium limits live in one place.** `ProGate` answers every "may I add one
more?", taking a single `hasFullAccess` flag — true for a bought copy and equally
true for a running trial, so no screen has to tell the two apart. The trial is
the app's own, because StoreKit has no introductory offer for a non-consumable:
`Trial` holds the rules with no storage and no clock so they can be tested
directly, `TrialService` keeps the one start date in `UserDefaults`, and
`StoreManager` puts the purchase and the trial behind that single flag. The start
date is per-installation on purpose — a parent should not find their trial spent
on a new iPad by a device they no longer own.

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
  -project Burrow.xcodeproj \
  -scheme Burrow \
  -destination 'generic/platform=iOS Simulator'
```

Tests use the same scheme, but need a booted simulator rather than a generic
destination:

```sh
xcodebuild test \
  -project Burrow.xcodeproj \
  -scheme Burrow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Both commands run in CI on every push (`.github/workflows/build.yml`), where
the simulator is looked up with `simctl` rather than named.

## Localization

`Burrow/Resources/Localizable.xcstrings` holds every user-facing string in
English (source), Dutch, German, French and Spanish. Adding a language means
adding it to the catalog and to `knownRegions` in the project file; nothing in
the code changes.
