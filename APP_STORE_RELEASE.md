# Releasing Burrow

The pipeline is the one Scaleway ControlRoom uses, on GitHub's `xcode-27`
runner image (the iOS 27 SDK App Store Connect requires). Three workflows, all
started by hand from the repository's **Actions** tab except where noted:

| Workflow | Does | Needs |
| --- | --- | --- |
| **Screenshots** | Builds for the simulator, takes 7 scenes × 5 languages × iPhone and iPad, commits them to `AppStore/screenshots/` | nothing |
| **Release to TestFlight** | Archives, signs in the cloud, uploads to TestFlight; pushes the store text and screenshots | `ASC_*` secrets |
| **Website** | Uploads `website/` with the icon and screenshots to `vandijkcloud.nl/Burrow/` (also runs on its own after Screenshots, and on website changes on `master`) | `FTP_*` secrets |

The store text lives in `APP_STORE_METADATA.md` and the review notes in
`APP_REVIEW_NOTES.md`; `Scripts/metadata_to_fastlane.py` reads both, checks the
App Store limits (CI runs it on every push) and writes fastlane's layout.

## Once, before the first release

### 1. Secrets

GitHub → Settings → Secrets and variables → Actions → *New repository secret*:

- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`: App Store Connect → Users and
  Access → Integrations → App Store Connect API. The key must have the
  **Admin** role (cloud signing creates the distribution certificate). The same
  key ControlRoom uses works: it is per team, not per app.
- `FTP_HOST`, `FTP_USERNAME`, `FTP_PASSWORD`: an FTP user for the folder behind
  `vandijkcloud.nl/Burrow/`. If the user's root is not that folder, add a
  repository **variable** `FTP_DIR` with the path, e.g. `/Burrow/`.

### 2. App Store Connect

- **App record:** Apps → + → New App: iOS, name **Burrow: Kids Music & Video**,
  primary language English (U.S.), bundle ID `com.pvd.burrow`, SKU `burrow`.
- **iCloud:** in the developer portal, Identifiers → `com.pvd.burrow`, turn on
  iCloud (CloudKit) and assign the container `iCloud.com.pvd.burrow`. Cloud
  signing creates the App ID but may not attach the container; if the archive
  fails on the iCloud entitlement, this is why.
- **App Review Information** (before the first metadata push: fastlane crashes
  with `No data` without it): contact name, phone, email; sign-in not required.
  The notes are pushed from `APP_REVIEW_NOTES.md`.
- **In-app purchases:** create both non-consumables, then add them to the
  version page under *In-App Purchases* before submitting:
  - `com.pvd.burrow.pro`, *Burrow Full*, €9.99
  - `com.pvd.burrow.trial`, *14-day Trial*, free
  Each needs a review screenshot of the purchase screen: **Screenshots** takes
  it as `AppStore/purchase-review.png`, and **Store setup** uploads it.
- **App Privacy:** Data Not Collected. **Age rating:** answer the questionnaire.
  **Category:** Education / Entertainment (pushed); do **not** tick Made for
  Kids (see the YouTube note in `APP_STORE_METADATA.md`).

## Each release

1. Raise `MARKETING_VERSION` in the project for a new version (the build number
   is the commit count, never set by hand).
2. Run **Screenshots** if the app looks different. It commits to the branch it
   ran on.
3. Run **Release to TestFlight** on that branch.
4. Test the build in TestFlight, then submit for review in App Store Connect.

## If archiving says the certificate limit is reached

Every run archives on a fresh runner, which makes Apple create an "Apple
Development: Created via API" certificate. The release workflow revokes the one
it made at the end of the run (`Scripts/revoke_runner_certificates.py`), so
they no longer pile up. Certificates left by older runs, here or in another app
on the same team, are cleared by running **Revoke stale certificates**: it
revokes every "Created via API" development certificate and leaves the
distribution certificate and the ones made in Xcode alone.
