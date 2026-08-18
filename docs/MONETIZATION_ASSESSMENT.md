# Can Burrow make money? — assessment, August 2026

A read of the shipped code, `APP_STORE_METADATA.md` and `APP_REVIEW_NOTES.md`
against the state of the App Store. Written to be argued with, not agreed with.

## Short answer

Yes, but on the current plan the number is **low hundreds of euros in year one**,
not income. The product thesis is right and unusually well executed; the
*packaging and distribution* are the underbuilt half. Four changes — one of them
free — plausibly move it to low thousands.

There is also one hard blocker (no app icon exists) and one structural risk
(YouTube) that can zero the whole thing.

---

## 1. Blockers before this can ship at all

- **There is no app icon.** `AppIcon.appiconset/Contents.json` declares a single
  1024×1024 universal entry with no `filename`, and the repository contains zero
  `.png`/`.jpg`/`.pdf`/`.svg` files anywhere. App Store Connect rejects uploads
  without a 1024 icon. For a kids app the icon is also the single largest driver
  of tap-through in browse — this is not a checkbox, it is a design task.
- **No screenshots** (already on the metadata checklist, unchecked). See §4e —
  for this app they carry the entire conversion argument.
- **No marketing page.** `website/` has `privacy.html` and `support.html` only;
  Marketing URL is `_TODO_`. There is no owned funnel, which matters more than
  usual here because organic App Store discovery for a new app is effectively
  zero.
- `Config/Burrow.storekit` has an empty `_developerTeamID`, and the entitlement
  still points at a container that needs the real team (README already says so).
- Every box in *Metadata Checks Before Submission* is unticked, including
  "non-English descriptions reviewed by a native speaker". See §4b — that one is
  not cosmetic.

## 2. The risk that could zero it: YouTube

`YouTubeWebView.swift` plays the official IFrame embed, but modifies it hard:

- `controls: 0`, `disablekb: 1`, `fs: 0`, `modestbranding: 1`, `iv_load_policy: 3`
- an active caption-suppression sweep — `setOption('captions', 'track', {})`
  every 700 ms for ten ticks, with a comment explaining that this is the only
  thing that actually kills auto-generated subtitles
- per `APP_REVIEW_NOTES.md`, a transparent overlay so taps cannot reach the
  player's own controls
- `baseURL: https://localhost` to make the page claim a non-YouTube origin,
  because loading it as youtube.com made the player reject every video

Individually each is defensible; together they are a deliberate campaign against
the player's own UI. YouTube's API Services Terms of Service and Developer
Policies require that you not modify, obscure or disable parts of the embedded
player, oblige you to check whether embedded content is "made for kids" via the
Data API before embedding it, and place extra duties on Child-Directed API
Clients — including notifying Google of the child-directed nature of the client.
Burrow does none of the checking and none of the notifying.

Two consequences, of very different shapes:

- **Apple:** probably waved through, but Guideline 5.2.3 (unauthorized
  third-party audio/video streaming) is exactly the hook reviewers have used on
  YouTube-playing apps before. Call it a coin flip. A 5.2.3 rejection is a
  rewrite, not a resubmit.
- **Google:** can revoke embed access whenever they notice. If they do, every
  video tile in every installed copy breaks *simultaneously*, after people paid
  €9.99 for it, and there is nothing you can ship to fix it. That is the tail
  risk that should decide this.

Suppressing captions also removes the app's only accessibility path for a deaf
or hard-of-hearing child. Worth saying out loud.

**Recommendation: ship v1 without YouTube.** The cost of keeping it is larger
than it looks — see §4c.

## 3. The monetization design problem

Free tier: 1 profile, 5 tiles, 7 items per playlist, 2 games. That is **35
tracks for one child** — and for the median target user (one toddler, a dozen
favourite songs) it is the *finished product*. The wall never arrives. You have
built a generous free app with a paywall bolted to the parts of the ceiling
nobody reaches.

Ranked by how much pull each trigger actually has:

1. **2nd profile** — real pull, but only for families with two-plus kids.
2. **8th playlist item** — the one that genuinely bites; 7 is a short playlist.
3. **6th tile** — five tiles is a lot of tiles for a three-year-old.
4. **3rd game** — weakest; the games are a nice-to-have, not the job.

Options, best first:

- **Go hard paywall or full-featured trial.** Median freemium download→paid is
  **2.18%**; hard-paywall apps convert at **12.11%**. For a utility with no
  network effect, no content cost and no server bill, a 7-day everything-unlocked
  trial that then locks is likely to out-earn this freemium split by several
  times, and it removes the "why would I pay" problem entirely.
- If you keep freemium, **cut items per playlist to ~3** and leave the rest
  alone. That is the trigger a single-child household actually hits, and it hits
  it on day one while intent is highest.
- **€9.99 is the right price and the wrong shelf.** Against a Toniebox or Yoto at
  $99.99 it is a bargain, and the German/Dutch parents who own those are your
  buyer. Against the nearest direct App Store competitors — *Easy Kids Video
  Player* at $0.99, *Kids Audio*, *Montessori Music Player* — it is 10×. The
  metadata has to do that anchoring work explicitly; right now no locale's
  description mentions what the alternative costs.
- `familyShareable: true` is correct and worth saying in the description.

Credit where due: `StoreManager` reads `Transaction.currentEntitlements`, which
is served from the on-device signed cache, so a paying parent keeps their unlock
offline and on a new device. That is the bug class that generates "I paid and
lost it" one-stars, and it is not present here.

## 4. ASO and metadata review

### What is already right

- **Five languages, fully localized, in the app *and* in the metadata.**
  339 strings × de/es/fr/nl, all `translated`. Almost no indie app does this, and
  it is the single highest-leverage asset in the repository. The language set is
  also the correct one: DE/NL/FR/ES is close to the Toniebox-native,
  privacy-sensitive, euro-paying audience. Germany especially — Tonies is a
  German product and `werbefrei` / `Bildschirmzeit` are the right words there.
- **The positioning line is genuinely good copy.** "Most apps for children are
  built to keep them watching. This one is built to stop." It is differentiated,
  memorable, and true of the code. Keep it as the first line everywhere.
- Field lengths are all inside their limits, keywords use singulars and no
  spaces after commas. That discipline is rarer than it should be.
- Ads are the loudest complaint in this category — roughly **35% of all 1-star
  reviews in kids apps** are about advertising, the highest ratio of any
  category, and subscription fatigue ("$13/month for a 4-year-old's app") is
  close behind. "No ads, no subscription, one purchase" aims straight at both.

### Problems, most expensive first

**a) "Burrow" is dead weight in the name field.** Zero search volume, no
semantic tie to the category, and the name field is the most heavily weighted
input in App Store search. You are spending your best 30 characters on a word
nobody types. It also won't be yours: two apps already ship as *Burrow* (Burrow
CRM, Burrow App), and Burrow Inc. holds a US registration on BURROW (reg.
5183579) — different class, so no legal fight, but no brand-search win either.
Put the searched words first: `Kids Music Player: Burrow`, or drop the brand
from the name field for v1 and let it live in the icon and the app itself.

**b) The localized names promise content the app does not have.** German
`Burrow: Musik & Hörspiel` and French `Burrow : Comptines & Vidéo` tell a parent
that audio dramas and nursery rhymes are *inside*. They are not — the parent
supplies everything. The keyword fields repeat the mistake: `Hörspiel`,
`Einschlafen`, `cuentos`, `nanas`, `berceuse`, `histoires`, `dessin` are all
content words for a container app. In a category where expectation mismatch is
already the top complaint, this buys refunds and 1-stars **in your two best
markets**. Sell the container, not the content: `dein eigener Player`,
`ton propre lecteur`.

**c) You are on the wrong shelf, and YouTube is why.** Because of the embed you
correctly rule out the Kids Category and go in under Education — one of the
harshest categories on the store — and you give up the Kids browse placement
that is the only meaningful free discovery channel for this exact audience. Drop
YouTube and you get Kids Category, "Made for Kids", *and* the honest claim "no
third-party anything, no network calls at all", which is the pitch you are
already making. This is the free lever, and it is the biggest one.

**d) The keyword fields target the wrong intent.** `safe`, `calm`, `curated`,
`parental` are low-intent or marketer's words — no parent searches "curated".
Missing entirely, in every locale, is the highest-intent search this app can
actually win: *plays my own files, works with no wifi, in the car*. Add
`mp3`, `own music`, `local file`, `no ads`, `no wifi`, `car`, `audiobook`,
`sleep`. Also, Apple combines name + subtitle + keywords, so your own
non-repetition checklist item is currently violated depending on which subtitle
you pick — `Music`/`Video` sit in the EN name while `player` sits in keywords and
in two of the three candidate subtitles. Choose the subtitle that *adds*
searchable words rather than repeating them: something like
`Your own songs, offline, no ads` beats `Music and video, nothing else`, and
frees three keyword slots.

**e) Screenshots carry the whole argument, and none exist.** Shot 1 must be a
real toddler-sized grid of familiar-looking tiles. **Shot 2 must pre-empt "does
it come with songs?" and answer it as a feature** — "Use the music you already
own." Getting that objection handled before the install is worth more than every
keyword change above, because it is the objection that decides whether the free
tier converts or gets a refund.

**f) Promotional text is your only no-review-needed field.** Use it seasonally —
car trips, flights, Christmas, summer holidays. The current text is good; rotate
it rather than freezing it.

## 5. The number

Assumptions stated so you can move them:

| Input | Conservative | Optimistic |
| --- | --- | --- |
| Year-1 installs (5 locales, no marketing, Education category) | 500 | 3,000 |
| Download→paid | 1.0% | 3.0% |
| Net per sale (€9.99, 85% Small Business Program) | €8.49 | €8.49 |
| **Year-1 net** | **≈ €40** | **≈ €760** |

Midpoint on the plan as written: **low hundreds of euros**. Installs are the
weak term, not conversion — organic discovery for a new app is close to zero and
90%+ of App Store revenue accrues to the top 1%. Do enrol in the Small Business
Program; 85% vs 70% is a free 21% raise.

What changes the order of magnitude, by leverage:

1. **Drop YouTube → Kids Category + Made for Kids.** Browse placement to the
   right audience. Plausibly 3–10× installs. Costs one feature and zero euros.
2. **Trial-then-buy instead of the generous free tier.** 2.18% → 12.11% median
   is roughly 5× on conversion.
3. **Germany first, to the Tonies/Yoto audience.** A large, identified,
   already-paying, screen-time-anxious cohort whose €99 device you undercut by
   90% — and your German localization is finished. One good post in a German
   parenting community will outperform a month of keyword tuning.
4. **Fix the name field** and the content-promising localized names.

All four landing: **low thousands in year one** (order €2k–8k). Still not a
living. But the margin is 100% — CloudKit-only means no server bill, ever — the
five localizations compound, and there is no content licensing to renew. It is a
product that cannot become a liability, which is worth more than it sounds.

## 6. What I would do, in order

1. Draw an app icon. Nothing ships without it.
2. Decide on YouTube. My recommendation is cut it for v1: it costs you the Kids
   Category, it is the one thing that can break the app remotely after people
   have paid, and removing it makes your central claim literally true.
3. Rewrite the five name/subtitle/keyword sets: searched words first, no content
   promises, add the offline/own-files/car intent.
4. Rebalance the paywall — trial, or 3 items per playlist.
5. Screenshots that answer "does it come with songs?" in frame 2.
6. Get the German descriptions read by a native speaker before submitting.
