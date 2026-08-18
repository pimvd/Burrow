# Games tab

A third child tab holding small, built-in games. Games ship in the binary,
are written in SwiftUI, and each profile shows only the games the parent
switched on.

## Why this shape

A tile is content a parent authored: a title, artwork and a playlist, synced
through CloudKit and reversible through the trash. A game is none of those —
it is code, identical on every device, and there is nothing about it to sync.
Modelling games as a third `TileCategory` would put rows in the store whose
only job is to point at a hardcoded view, and would add a case to
`TileCategory.allowedSourceTypes` that means nothing.

So games are a fixed catalog in code, following `AvatarCatalog` and
`ThemePalette`, and the only per-profile state is which of them are on.

## Data model

Amend `BurrowSchemaV1` in place and bump it to `1.1.0`. No `V2`, no
duplicate model classes, `stages` stays empty: the app has not shipped, so
there are no stores to migrate but the author's own. Both additions are
CloudKit-safe by the rules already followed in this repo — a defaulted array
and an optional string.

### `ChildProfile.enabledGameIDs: [String]`

Which games this profile may see. Mirrors `visibleSharedTileIDs`
(`ChildProfile.swift:32`) exactly, including its accessor:

```swift
func setGame(_ identifier: String, enabled: Bool) {
    var ids = Set(enabledGameIDs)
    if enabled { ids.insert(identifier) } else { ids.remove(identifier) }
    enabledGameIDs = Array(ids)
    lastModified = Date()
}
```

Deliberately not a `GameActivation` model. A separate model only earns its
keep once games need persisted per-profile state — difficulty, progress,
scores. Nothing here does, and adding the model later is no harder than
adding it now.

Stored by string identifier rather than UUID so a hand-written catalog entry
stays readable, and so a game removed from a future build leaves behind an
inert string rather than a dangling reference.

### `UsageSession.gameIdentifier: String?`

`nil` on every media row. Set on game rows, so the parent screens can tell
the two apart and label games without a reverse lookup.

## Statistics: games as pseudo-tiles

`StatisticsService` decides what a row *means* from `mediaItemID == nil`
alone — that is the open-marker/play-row split, relied on in five places
(`StatisticsService.swift:124,149,183,213,232`). A game row with a nil
`mediaItemID` would be silently counted as an opening worth zero seconds, and
every second of game time would disappear from the totals.

Rather than teach those five functions a new concept, each game carries a
stable hardcoded UUID and stands in as its own tile:

| Row | `tileID` | `mediaItemID` | `gameIdentifier` | `durationSeconds` |
|---|---|---|---|---|
| Game opened | game's UUID | `nil` | set | `0` |
| Game played | game's UUID | game's UUID | set | real seconds |

The existing scheme then works untouched. `totalsPerTile` groups each game as
its own row, and `playCounts` reads naturally as "Matching Pairs, played 5
times". The UUID is a literal in the catalog, never generated, so rows keep
resolving across launches and devices.

The only statistics change is display: anything resolving a `tileID` to a
title must fall back to `GameCatalog` when no `Tile` matches. That is
`TileStatisticsView` and the tile rows inside `StatisticsView`.

## Screen time

No work beyond one line. `ScreenTimeCoordinator` is a whole-session timer,
not a per-activity budget — `startSession(limitMinutes:)` runs from the
moment a profile is picked and ticks regardless of what the child is doing
(`ScreenTimeCoordinator.swift:31`). Games are inside that session already.

`TimesUpView` is presented from `ChildHomeView` above the `TabView`
(`ChildHomeView.swift:44`), so it already covers a Games tab. The expiry
handler at `ChildHomeView.swift:52` clears `presentedTile`; it gains a
matching `presentedGame = nil`.

## Components

### `GameCatalog` (`Burrow/Games/GameCatalog.swift`)

The fixed list, in the shape of `AvatarCatalog`.

```swift
struct Game: Identifiable, Sendable {
    let identifier: String       // stable, stored in enabledGameIDs
    let id: UUID                 // stable literal, used as pseudo-tile ID
    let localizedTitle: String
    let symbolName: String
}
```

Plus `static let all: [Game]`, `game(identifier:)`, and `game(id:)` for the
statistics fallback. No age metadata: availability is the parent's decision
and nothing else's.

The view itself is resolved by a separate `@ViewBuilder` switch on
`identifier` in `GameHostView`, not stored in the struct — keeping `Game` a
plain `Sendable` value.

### `ChildTab` (`Burrow/Views/Child/ChildTab.swift`)

`ChildHomeViewModel.selectedCategory` is typed `TileCategory`
(`ChildHomeViewModel.swift:9`). A third tab must not become a third
`TileCategory`, so tab selection moves to its own enum:

```swift
enum ChildTab: Hashable { case music, video, games }
```

`selectedCategory: TileCategory` becomes `selectedTab: ChildTab`, and
`tileGrid(for:)` in `ChildHomeView` keeps taking a `TileCategory` — the two
music and video tabs pass theirs explicitly. `ChildHomeViewModel` also gains
`presentedGame: GameCatalog.Game?` beside the existing `presentedTile`.

`TileCategory` is left exactly as it is.

### Games tab in `ChildHomeView`

A third `tabItem` (`gamecontroller` symbol), showing a grid of the profile's
enabled games. Card and grid reuse the existing look — `profile.layoutScale`
for sizing, `.calmCard`, `.buttonStyle(.calm)` — so game tiles read as native
beside Music and Video. A game card shows its SF Symbol on the theme tint
rather than artwork, since games have no image to store.

`AgeLayoutScale` still drives *layout* here, as it does in `TileGridView.swift:17`.
That is visual sizing only and is unrelated to which games are available.

### `GameHostView` (`Burrow/Views/Child/GameHostView.swift`)

Full-screen cover, mirroring `NowPlayingView`'s lifecycle: a close button in
the same position, `.statusBarHidden()`, `onAppear`/`onDisappear` driving the
recorder. Resolves `identifier` to a concrete game view.

### `MatchingPairsGame` (`Burrow/Games/MatchingPairsGame.swift`)

The one game. A grid of face-down cards using SF Symbols on the profile's
theme colours; two taps reveal, a match stays up, a mismatch turns back after
a beat. No sound — the child interface has no sound effects and games do not
introduce them. No score, no timer, no fail state; it simply completes and
offers to play again.

### `UsageRecorder.beginGame` / `endGame`

Alongside the existing `beginTile`/`endTile`, writing the two row kinds in
the table above. The one-second floor on `finishCurrentEntry`
(`UsageRecorder.swift:63`) applies to games too.

### `ProGate.gamesPerProfile`

A fourth `Limit` case: `2` free, `Int.max` paid, plus its localized message
in the same voice as the existing three (`ProGate.swift:50`). Enforced where
the parent switches a game on, not where the child plays.

### `ParentGamesView` (`Burrow/Views/Parent/ParentGamesView.swift`)

Reached from `ParentSettingsView` via a new `ParentDestination.games`
(`AppRouter.swift:15`), placed in the first section beside Profiles and
Tiles. A profile picker matching `TileListView`'s, then one toggle per game.
Switching on a game past the free limit shows the ProGate message and offers
the purchase, matching how the tile limit already behaves.

Because the limit is enforced at the toggle, a profile could otherwise arrive
over the limit by another route — importing a package written on a paid
device. The child tab therefore also takes only the first
`gamesPerProfile.maximum(isPro:)` enabled games, ordered by their position in
`GameCatalog.all`, so the free tier holds however the profile got there.
Nothing is switched off in the store: unlocking restores the rest.

### `ExportPackage`

`ExportPackage.Profile` carries the profile's fields (`ExportPackage.swift:26`).
`enabledGameIDs` is added there and in both directions of the mapping
(`:38`, `:51`) so activation survives export and import. Unknown identifiers
on import are dropped rather than kept, so a package from a newer build
cannot switch on a game this build does not have.

## Testing

- `ProGate.gamesPerProfile` — boundaries at 2 free and unlimited paid.
- `ChildProfile.setGame(_:enabled:)` — add, remove, idempotent re-add, and
  `lastModified` bumped.
- `StatisticsService` over mixed media and game rows — game seconds land in
  the duration totals, game openings land in the opening counts, and neither
  double-counts. This is the regression the pseudo-tile scheme exists to
  prevent, so it is the test that matters most.
- `GameCatalog` — identifiers and UUIDs are unique, and every entry resolves
  to a view.
- `ExportPackage` — round-trips `enabledGameIDs`, and drops unknown ones.
- A free profile carrying more enabled games than the limit shows only the
  first two to the child, and shows all of them again once unlocked.
- Matching Pairs — match and mismatch transitions, and completion.

## Localization

New strings go into `Localizable.xcstrings` in English, Dutch, German, French
and Spanish: the Games tab label, the game title, the ProGate limit message,
the parent screen's title and its rows, and the accessibility labels on game
cards and the close button.

## Out of scope

- More games. Each further game is one file plus a catalog entry.
- Per-game settings, difficulty, scores or saved progress.
- Games in the trash. A game cannot be deleted, only switched off.
- Sound.
