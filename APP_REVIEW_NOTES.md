<!-- App Store Connect caps App Review Information → Notes at 4000 characters.
     Everything below the heading is pasted into that field — keep it under the cap. -->

# App Review Notes — Burrow

Version 1.0.

Burrow is a media player for young children that plays only what a parent puts into it. A parent creates "tiles" — each is one playlist, music or video — and fills them with audio/video files from the device, Apple Music songs, or YouTube links. The child sees only those tiles: no search, no browsing, no recommendations, no way to reach anything the parent did not add. There is no account or sign-in, so no demo account applies. Localized in English, German, Spanish, French and Dutch.

Reaching the parent area:
- Tap the person icon in the top-left of the child screen, then the gear icon.
- A parental gate asks for a year of birth. Enter any year that makes the person an adult (for example 1990). This guards all settings, statistics, and the purchase.

In-app purchase:
- `com.pvd.burrow.pro` (Burrow Full), a **non-consumable** one-time purchase at €9.99. No subscriptions.
- `com.pvd.burrow.trial` (14-day Trial), a **free non-consumable** that starts the trial, per guideline 3.1.1.
- Free: one child profile, five tiles per profile, three items per playlist, two games.
- Full: unlimited profiles and tiles, 50 items per playlist, all six games.
- Purchase path: hit any limit — a second profile, a sixth tile, a fourth playlist item, a third game — and the purchase screen opens with the reason shown. Also reachable from parent settings.
- **Free trial:** the purchase screen offers "Try everything free for 14 days", which buys the free 14-day Trial item. Its purchase date starts the trial; it opens every limit for 14 days, costs nothing and needs no cancelling. When it ends the app returns to the free limits with the parent's content intact.
- To see the paid state without paying: parent area → Unlock Burrow → "Try everything free for 14 days".
- Restore: "Restore purchase" on that screen.
- Both are read from StoreKit 2 current entitlements at launch. No server.

Content and third-party playback:
- **YouTube:** parent-supplied links only, played through YouTube's embedded player. The child cannot search, browse, or follow links out; the embed is overlaid so taps cannot reach YouTube's own controls. In a music tile only the sound plays.
- **Apple Music:** requires the parent's own subscription. Its permission prompt appears only when an Apple Music item is added, not at launch.
- Because YouTube is involved, the app is **not** submitted under the Kids Category and is not marked "Made for Kids".
- The app tells the parent — where a link is added, and on the purchase screen — that YouTube playback depends on Google and works only for as long as YouTube allows it, and that unlocking lifts Burrow's own limits rather than paying for YouTube or Apple Music.

Permissions and privacy:
- No data collected: no analytics, ads, tracking, ATT prompt, or account. We run no server.
- Profiles, tiles, playlists and statistics sync through the user's **own** private CloudKit database (`iCloud.com.pvd.burrow`). The developer has no access.
- Media the parent adds stays in the app's own storage on the device.
- Local notifications only, for an optional monthly backup reminder the parent turns on.
- Privacy policy: `vandijkcloud.nl/Burrow/privacy.html`

Suggested reviewer flow:
1. On first launch, create a child profile, then open a tab.
2. Parent area: person icon → gear → gate (any adult birth year).
3. Tiles → add a tile → add an item (a local file, or a YouTube link).
4. Back on the child side, tap the tile to play. Closing the player keeps music going and shows a bar to stop it; video stops when closed.
5. Games: six calm games, two available free.
6. Trigger the paywall: Profiles → add a second profile.
6b. Or start the 14-day trial from that screen to see the unlocked state.
7. Buy Burrow Full, then confirm the limits lift.
8. Export and import: create a backup — a zip through the share sheet.

Support: `pim@vandijkcloud.nl`. Happy to clarify in the Resolution Center.
