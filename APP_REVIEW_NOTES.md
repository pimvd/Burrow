<!-- App Store Connect caps App Review Information → Notes at 4000 characters.
     Everything below the heading is pasted into that field — keep it under the cap. -->

# App Review Notes — Burrow

Version 1.0.

Burrow is a media player for young children that plays only what a parent puts into it. A parent creates "tiles" — each tile is one playlist, music or video — and fills them with audio/video files from the device, Apple Music songs, or YouTube links. The child sees only those tiles: no search, no browsing, no recommendations, no way to reach anything the parent did not add. There is no account or sign-in, so no demo account applies. Localized in English, German, Spanish, French and Dutch; follows the device language.

Reaching the parent area:
- Tap the person icon in the top-left of the child screen, then the gear icon.
- A parental gate asks for a year of birth. Enter any year that makes the person an adult (for example 1990). This guards all settings, statistics, and the purchase.

In-app purchase:
- One product: `com.pvd.burrow.pro` (Burrow Full), a **non-consumable** one-time purchase at €9.99. No subscriptions.
- Free: one child profile, five tiles per profile, seven items per playlist, two games.
- Full: unlimited profiles and tiles, up to 50 items per playlist, all six games.
- Purchase path: hit any of those limits — add a second profile, a sixth tile, an eighth playlist item, or a third game — and the purchase screen opens with the reason shown. It is also reachable from the parent settings list.
- Restore: "Restore purchase" on that screen.
- The entitlement is read from StoreKit 2 current entitlements on each launch. No server component.

Content and third-party playback:
- **YouTube:** parent-supplied links only, played through YouTube's embedded player. The child cannot search, browse, or follow links out; the embed is overlaid so taps cannot reach YouTube's own controls. In a music tile the picture stays hidden and only the sound plays.
- **Apple Music:** requires the parent's own subscription. The Apple Music permission prompt appears only when a parent adds an Apple Music item, not at launch.
- Because YouTube is involved, the app is **not** submitted under the Kids Category and is not marked "Made for Kids".

Permissions and privacy:
- No data collected: no analytics, ads, tracking, ATT prompt, or account. There is no server of ours.
- Profiles, tiles, playlists and usage statistics sync through the user's **own** private CloudKit database (`iCloud.com.pvd.burrow`). The developer has no access.
- Audio/video/pictures the parent adds stay in the app's own storage on the device.
- Local notifications only, for an optional monthly backup reminder the parent turns on.
- Privacy policy: `https://vandijkcloud.nl/burrow/privacy.html`

Suggested reviewer flow:
1. On first launch, create a child profile, then open a tab (Music / Video / Games).
2. Parent area: person icon → gear → parental gate (any adult birth year).
3. Tiles → add a tile → add a playlist item (a local file, or paste a YouTube link).
4. Back on the child side, tap the tile to play. Closing the player keeps music going and shows a bar to stop it; video stops when its player closes.
5. Games: six calm games, two available free.
6. Trigger the paywall: Profiles → add a second profile.
7. Buy Burrow Full, then confirm the limits lift.
8. Export and import: create a backup, which produces a zip through the share sheet.

Support: `pim@vandijkcloud.nl`. Happy to clarify via the Resolution Center.
