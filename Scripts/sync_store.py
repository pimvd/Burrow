#!/usr/bin/env python3
"""Sets up the parts of App Store Connect that fastlane deliver does not:
the in-app purchases and the app's price and availability.

Run by the "Store setup" workflow. Reads AppStore/store.json; needs
ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (see Scripts/asc.py).

Safe to run again: whatever exists is updated or left alone. Prices and
availability are only set where none exist yet, so a price changed by hand in
App Store Connect is never overwritten. Each in-app purchase's review
screenshot is uploaded from AppStore/purchase-review.png once that exists.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import NotFound, SyncError, client_from_environment  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "AppStore" / "store.json").read_text(encoding="utf-8"))
REVIEW_SCREENSHOT = ROOT / "AppStore" / "purchase-review.png"


class Store:
    def __init__(self, api):
        self.api = api
        self._territories = None

    def get(self, path, params=None):
        return self.api.request("GET", path, params)

    def post(self, path, body):
        return self.api.request("POST", path, body=body)

    def patch(self, path, body):
        return self.api.request("PATCH", path, body=body)

    def territories(self):
        if self._territories is None:
            self._territories = [t["id"] for t in self.get("/v1/territories", {"limit": "200"})["data"]]
        return self._territories

    def run(self):
        apps = self.get("/v1/apps", {"filter[bundleId]": CONFIG["bundle_id"]})["data"]
        if not apps:
            raise SyncError(f"No app with bundle ID {CONFIG['bundle_id']} in App Store Connect.")
        app = apps[0]["id"]
        print(f"App {CONFIG['bundle_id']}: {app}")
        self.app_price(app)
        self.app_availability(app)
        for product in CONFIG["in_app_purchases"]:
            self.in_app_purchase(app, product)

    # The app: free, everywhere -------------------------------------------------

    def app_price(self, app):
        try:
            schedule = self.get(f"/v1/apps/{app}/appPriceSchedule", {"include": "manualPrices"})
            if schedule.get("included"):
                print("App price: already set, left alone.")
                return
        except NotFound:
            pass
        territory = CONFIG["price_territory"]
        points = self.get(f"/v1/apps/{app}/appPricePoints",
                          {"filter[territory]": territory, "limit": "200"})["data"]
        point = next(p for p in points if float(p["attributes"]["customerPrice"]) == CONFIG["app_price"])
        self.post("/v1/appPriceSchedules", {
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}},
                    "baseTerritory": {"data": {"type": "territories", "id": territory}},
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${price}"}]},
                },
            },
            "included": [{
                "type": "appPrices", "id": "${price}",
                "attributes": {"startDate": None},
                "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": point["id"]}}},
            }],
        })
        print(f"App price: set to {CONFIG['app_price']} ({territory}), every territory follows.")

    def app_availability(self, app):
        try:
            self.get(f"/v1/apps/{app}/appAvailabilityV2")
            print("App availability: already set, left alone.")
            return
        except NotFound:
            pass
        territories = self.territories()
        self.post("/v2/appAvailabilities", {
            "data": {
                "type": "appAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}},
                    "territoryAvailabilities": {"data": [
                        {"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]},
                },
            },
            "included": [{
                "type": "territoryAvailabilities", "id": f"${{{t}}}",
                "attributes": {"available": True},
                "relationships": {"territory": {"data": {"type": "territories", "id": t}}},
            } for t in territories],
        })
        print(f"App availability: all {len(territories)} territories, and new ones as they come.")

    # In-app purchases ---------------------------------------------------------

    def in_app_purchase(self, app, product):
        pid = product["product_id"]
        attributes = {
            "name": product["reference_name"],
            "reviewNote": product["review_note"],
            "familySharable": product["family_sharable"],
        }
        found = self.get(f"/v1/apps/{app}/inAppPurchasesV2",
                         {"filter[productId]": pid, "limit": "200"})["data"]
        if found:
            iap = found[0]["id"]
            # Family Sharing cannot be turned off again once on; never send it twice.
            if found[0]["attributes"].get("familySharable"):
                attributes.pop("familySharable")
            self.patch(f"/v2/inAppPurchases/{iap}", {"data": {
                "type": "inAppPurchases", "id": iap, "attributes": attributes}})
            print(f"{pid}: updated")
        else:
            iap = self.post("/v2/inAppPurchases", {"data": {
                "type": "inAppPurchases",
                "attributes": {**attributes, "productId": pid, "inAppPurchaseType": "NON_CONSUMABLE"},
                "relationships": {"app": {"data": {"type": "apps", "id": app}}},
            }})["data"]["id"]
            print(f"{pid}: created")
        self.localizations(iap, product)
        self.iap_price(iap, product)
        self.iap_availability(iap, pid)
        self.review_screenshot(iap, pid)

    def localizations(self, iap, product):
        existing = {item["attributes"]["locale"]: item for item in self.get(
            f"/v2/inAppPurchases/{iap}/inAppPurchaseLocalizations", {"limit": "50"})["data"]}
        for locale, (name, description) in product["localizations"].items():
            attributes = {"name": name, "description": description}
            if locale in existing:
                self.patch(f"/v1/inAppPurchaseLocalizations/{existing[locale]['id']}", {"data": {
                    "type": "inAppPurchaseLocalizations", "id": existing[locale]["id"],
                    "attributes": attributes}})
            else:
                self.post("/v1/inAppPurchaseLocalizations", {"data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {**attributes, "locale": locale},
                    "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}},
                }})
        print(f"  names and descriptions: {', '.join(product['localizations'])}")

    def iap_price(self, iap, product):
        try:
            schedule = self.get(f"/v2/inAppPurchases/{iap}/iapPriceSchedule", {"include": "manualPrices"})
            if schedule.get("included"):
                print("  price: already set, left alone")
                return
        except NotFound:
            pass
        territory = CONFIG["price_territory"]
        points, params = [], {"filter[territory]": territory, "limit": "200"}
        path = f"/v2/inAppPurchases/{iap}/pricePoints"
        while path:
            page = self.get(path, params)
            points += page["data"]
            following = page.get("links", {}).get("next")
            path = following.replace("https://api.appstoreconnect.apple.com", "") if following else None
            params = None
        point = next(p for p in points if abs(float(p["attributes"]["customerPrice"]) - product["price"]) < 0.001)
        self.post("/v1/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                    "baseTerritory": {"data": {"type": "territories", "id": territory}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]},
                },
            },
            "included": [{
                "type": "inAppPurchasePrices", "id": "${price}",
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}},
                    "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}},
                },
            }],
        })
        print(f"  price: {point['attributes']['customerPrice']} in {territory}, equalized elsewhere")

    def iap_availability(self, iap, pid):
        try:
            self.get(f"/v2/inAppPurchases/{iap}/inAppPurchaseAvailability")
            print("  availability: already set, left alone")
            return
        except NotFound:
            pass
        territories = self.territories()
        self.post("/v1/inAppPurchaseAvailabilities", {"data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
            },
        }})
        print(f"  availability: all {len(territories)} territories")

    def review_screenshot(self, iap, pid):
        if not REVIEW_SCREENSHOT.exists():
            print(f"  review screenshot: none yet ({REVIEW_SCREENSHOT.relative_to(ROOT)} is missing)")
            return
        try:
            current = self.get(f"/v2/inAppPurchases/{iap}/appStoreReviewScreenshot")["data"]
            if current:
                print("  review screenshot: already there")
                return
        except NotFound:
            pass
        data = REVIEW_SCREENSHOT.read_bytes()
        reserved = self.post("/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "attributes": {"fileName": REVIEW_SCREENSHOT.name, "fileSize": len(data)},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}},
        }})["data"]
        for operation in reserved["attributes"]["uploadOperations"]:
            self.api.upload(operation, data[operation["offset"]:operation["offset"] + operation["length"]])
        import hashlib
        self.patch(f"/v1/inAppPurchaseAppStoreReviewScreenshots/{reserved['id']}", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "id": reserved["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("  review screenshot: uploaded")


def main():
    try:
        Store(client_from_environment()).run()
    except SyncError as error:
        print(f"::error::{error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
