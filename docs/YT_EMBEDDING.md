# Serving the YouTube player page from our own domain

Branch: `DONT_REMOVE/YT_EMBEDDING`. Not merged. This file is the handover.

## Why

YouTube's embedded player identifies its host through the HTTP `Referer`
header. On 9 July 2025 YouTube tightened that check, and WebView apps broke in
numbers with error 153 through that autumn, because a `WKWebView` does not send
the header the way a browser does.

Burrow already ran into this. The comment in the old loader recorded that
serving the page as youtube.com produced *"a 15x error for every video"*, and
the fix at the time was to claim `https://localhost` as the origin. That still
works, but it works because `localhost` is currently *accepted* as an embedder
origin — a convenience, not a contract, and one tick of the same enforcement
away from stopping.

This branch does the thing the enforcement actually asks for: it serves the
player page from a real origin we own, so the embed sends a genuine `Referer`.

It does **not** fix the two standing policy problems: the overlay in front of
the player, and the missing `status.madeForKids` lookup. It fixes the failure
that is actually likely.

## What changed

- **`website/player.html`** — new. The page the app loads. Must be published at
  `https://vandijkcloud.nl/burrow/player.html` for this branch to be worth
  anything; until it is, every playback silently takes the fallback path below.
- **`YouTubeLink.playerURL(videoID:)`** — builds the address. The identifier
  goes in the **fragment**, which browsers never send to a server, so our own
  web server logs cannot record what a child watched. A `?v=` query carries
  `playerPageVersion` so a changed page defeats a cached copy.
- **`YouTubeWebView`** — loads that URL instead of building a string.
  - **Fallback.** If the hosted page cannot be reached, it falls back once to
    the built-in copy under `https://localhost` — the exact pre-branch
    behaviour. Offline, or hosting down, and playback still works. This branch
    is never worse than master, only better when the page is reachable.
  - **One page load per playlist.** Subsequent items are handed to the open page
    through `window.burrowLoad(id)` rather than re-navigating, so a ten-song
    playlist fetches the shell once instead of ten times.
  - **Top frame is pinned.** A navigation policy allows the embed's own
    subframes but refuses anything that would replace the page itself or open a
    window. This matters more now that the top frame is remote.
  - `modestbranding` dropped — YouTube deprecated it in August 2023 and it has
    no effect.

## Before this ships

- [ ] Publish `website/player.html` at `https://vandijkcloud.nl/burrow/player.html`
      and open it in a browser to confirm it returns 200 over HTTPS
- [ ] Test a video on a device, then a playlist of three, then airplane mode
      (should fall back and still play once the network returns)
- [ ] Raise `YouTubeLink.playerPageVersion` whenever `player.html` changes
- [ ] Keep the fallback HTML in `YouTubeWebView` in step with `player.html`

## Copy that becomes wrong, and must change with it

`website/privacy.html` is **already updated on this branch**. These are not:

- [ ] **App Store descriptions, all five locales.** Every one says a version of
      *"Nothing is ever sent to us — there is no server of ours to send it to."*
      That is no longer true for a YouTube item. It stays true for everything
      else, so the honest line is narrower, not absent: nothing is sent to us
      except a request for one static page, and it does not say which video.
- [ ] **`APP_REVIEW_NOTES.md`**, which tells App Review there is no server of
      ours. Same correction. Watch the 4000-character cap; it is at 3,958.
- [ ] **`website/support.html`**, which repeats the promise in the FAQ.
- [ ] `README.md` opening line: "privacy-first, offline-first".

## The trade being made

We gain: the most likely breakage path becomes a supported configuration.

We lose: one real dependency on our own hosting, and a privacy claim that used
to be absolute becomes a claim with a footnote. The footnote is small and
defensible — a static file, no analytics, and the video identifier deliberately
kept out of the request — but "we have no server" was a good line and this is
the end of it.

It touches YouTube items only. Local files, Apple Music, the games and every
tile keep working with no network of ours involved, which is what the copy
should now say.
