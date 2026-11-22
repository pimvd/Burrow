#!/usr/bin/env python3
"""Puts the in-app purchases from AppStore/store.json up for review, which is
what ticking them under "In-App Purchases" on the version page does.

Run by the "Store setup" workflow when its submit_purchases input is on. Only a
purchase in READY_TO_SUBMIT is submitted; any other state is reported and left
alone, so running it again changes nothing. Apple's answer is printed as given.

It cannot do an app's first non-consumable: Apple answers
FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION, and the review submission
API has no item type for a purchase. Those are ticked under In-App Purchases
on the version page in App Store Connect and go to review with the version.
This is for the purchases that come after.
Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (see Scripts/asc.py).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import SyncError, client_from_environment  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "AppStore" / "store.json").read_text(encoding="utf-8"))


def purchases_to_submit(purchases, product_ids):
    """(product id, purchase) for each wanted purchase, and the ones not ready."""
    found = {p["attributes"]["productId"]: p for p in purchases}
    ready, waiting = [], []
    for pid in product_ids:
        purchase = found.get(pid)
        state = purchase["attributes"].get("state") if purchase else "NOT_FOUND"
        (ready if state == "READY_TO_SUBMIT" else waiting).append((pid, purchase, state))
    return ready, waiting


def main():
    api = client_from_environment()
    apps = api.request("GET", "/v1/apps", {"filter[bundleId]": CONFIG["bundle_id"]})["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle ID {CONFIG['bundle_id']}")
    purchases = api.request("GET", f"/v1/apps/{apps[0]['id']}/inAppPurchasesV2", {"limit": "200"})["data"]
    wanted = [product["product_id"] for product in CONFIG["in_app_purchases"]]
    ready, waiting = purchases_to_submit(purchases, wanted)

    for pid, _, state in waiting:
        print(f"{pid}: {state}, left alone")
    failed = False
    for pid, purchase, _ in ready:
        try:
            api.request("POST", "/v1/inAppPurchaseSubmissions", body={"data": {
                "type": "inAppPurchaseSubmissions",
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": purchase["id"]}}},
            }})
            print(f"{pid}: submitted")
        except SyncError as error:
            failed = True
            print(f"::error::{pid}: Apple refused the submission: {error}")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
