#!/usr/bin/env python3
"""Revokes the development certificates this CI run made, and only those.

Archiving with -allowProvisioningUpdates on a fresh runner makes Apple create
an "Apple Development: Created via API" certificate whose private key lives in
that runner's keychain alone. The runner is thrown away; the certificate is
not, and the team's certificate limit (shared by every app on the team) fills
up until archiving fails with "Your account has reached the maximum number of
certificates".

Run by the release workflow after the upload. It takes the SHA-1 fingerprints
of the certificates in the runner's keychain as arguments and revokes the App
Store Connect development certificates with the same fingerprint: never one
made elsewhere, such as on a Mac or by another app's run going at the same
time. Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (see Scripts/asc.py).

Never fails the job: the build is already uploaded by now, so a problem here
is reported as a warning.
"""
import base64
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import SyncError, client_from_environment  # noqa: E402

DEVELOPMENT_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT"}


def fingerprint(certificate_content):
    """The SHA-1 of a certificate's DER bytes, as `security -Z` prints it."""
    return hashlib.sha1(base64.b64decode(certificate_content)).hexdigest().upper()


def certificates_to_revoke(certificates, runner_fingerprints):
    """The development certificates whose fingerprint is one of the runner's."""
    wanted = {f.strip().upper() for f in runner_fingerprints if f.strip()}
    chosen = []
    for certificate in certificates:
        attributes = certificate.get("attributes", {})
        if attributes.get("certificateType") not in DEVELOPMENT_TYPES:
            continue
        content = attributes.get("certificateContent")
        if content and fingerprint(content) in wanted:
            chosen.append(certificate)
    return chosen


def list_certificates(api):
    certificates, path, params = [], "/v1/certificates", {"limit": 200}
    while path:
        page = api.request("GET", path, params)
        certificates += page.get("data", [])
        following = page.get("links", {}).get("next")
        path = following.removeprefix("https://api.appstoreconnect.apple.com") if following else None
        params = None
    return certificates


def main(runner_fingerprints):
    if not runner_fingerprints:
        print("No development certificate in the runner's keychain; nothing to revoke.")
        return
    try:
        api = client_from_environment()
        chosen = certificates_to_revoke(list_certificates(api), runner_fingerprints)
        if not chosen:
            print("None of the runner's certificates is on App Store Connect; nothing to revoke.")
        for certificate in chosen:
            attributes = certificate["attributes"]
            api.request("DELETE", f"/v1/certificates/{certificate['id']}")
            print(f"Revoked {attributes.get('name')} ({attributes.get('serialNumber')})")
    except (SyncError, OSError) as error:
        print(f"::warning::Could not revoke this run's development certificate: {error}. "
              "Revoke stale 'Created via API' certificates by hand if archiving reports the limit.")


if __name__ == "__main__":
    main(sys.argv[1:])
