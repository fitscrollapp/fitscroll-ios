#!/usr/bin/env python3
"""Set FitScroll subscription pricing + 7-day free trial intro offers.

Plan (A - Aggressive):
  - Monthly $1.99
  - Yearly $14.99
  - Lifetime $29.99 (must be created manually in ASC — non-consumable
    IAP POST is not supported by the REST API)

Flow for each auto-renewable subscription:
  1. Resolve the USA price point that matches the target customer price.
  2. Clear any existing prices on the subscription (preserveCurrentPrice=False).
  3. Create a price for every other territory using Apple's equalization
     endpoint on the USA price point — this gives us a "USA-equivalent"
     price for every territory Apple offers.
  4. Attach a 7-day free-trial introductory offer if one is not already
     attached, scoped to every territory the subscription is priced in.
"""

import json
import sys
import time

import asc_client as asc


TARGETS = {
    "fitscroll_monthly": "1.99",
    "fitscroll_yearly": "14.99",
}

GROUP_ID = "22029167"
BASE_TERRITORY = "USA"


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def get_all(path):
    """GET a paginated endpoint and stitch `data` + `included` together."""
    items, included = [], []
    url = path
    while url:
        s, data = asc.get(url)
        if s != 200:
            print(f"  GET {url} -> {s}: {json.dumps(data)[:400]}")
            return items, included
        items.extend(data.get("data", []))
        included.extend(data.get("included", []))
        next_link = data.get("links", {}).get("next")
        if not next_link:
            break
        # Strip the base so _request re-prefixes — asc_client accepts full URLs too
        url = next_link.replace(asc.BASE_URL, "")
    return items, included


def list_subscriptions():
    """Return dict of productId -> subscription row."""
    items, _ = get_all(f"/subscriptionGroups/{GROUP_ID}/subscriptions")
    return {row["attributes"]["productId"]: row for row in items}


def find_usa_price_point(sub_id, target_price):
    """Find a subscriptionPricePoint ID for USA matching the target price."""
    target = str(target_price)
    url = (
        f"/subscriptions/{sub_id}/pricePoints"
        f"?filter[territory]=USA&limit=200"
    )
    items, _ = get_all(url)
    for pp in items:
        customer_price = pp["attributes"].get("customerPrice")
        if customer_price == target:
            return pp["id"], customer_price
    # Fallback: try numeric comparison against e.g. "1.990", "1.9900"
    for pp in items:
        cp = pp["attributes"].get("customerPrice")
        if cp and float(cp) == float(target):
            return pp["id"], cp
    return None, None


def clear_existing_prices(sub_id):
    """Delete every existing price row on the subscription."""
    url = f"/subscriptions/{sub_id}/prices?limit=200"
    items, _ = get_all(url)
    for p in items:
        s, _ = asc.delete(f"/subscriptionPrices/{p['id']}")
        if s not in (200, 204):
            print(f"    ! failed to delete price {p['id']}: {s}")
    return len(items)


def get_equalized_price_points(base_pp_id):
    url = f"/subscriptionPricePoints/{base_pp_id}/equalizations?limit=200"
    items, _ = get_all(url)
    return items


def set_price_for_territory(sub_id, pp_id):
    payload = {
        "data": {
            "type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": False},
            "relationships": {
                "subscription": {
                    "data": {"type": "subscriptions", "id": sub_id}
                },
                "subscriptionPricePoint": {
                    "data": {"type": "subscriptionPricePoints", "id": pp_id}
                },
            },
        }
    }
    s, resp = asc.post("/subscriptionPrices", payload)
    if s in (200, 201):
        return True, None
    raw = json.dumps(resp)
    if "DUPLICATE" in raw:
        return True, "duplicate"
    return False, raw[:300]


def set_prices(sub_id, target_price, label):
    step(f"{label} ({sub_id}) -> ${target_price}")

    base_pp_id, actual = find_usa_price_point(sub_id, target_price)
    if not base_pp_id:
        print(f"  ! No USA price point found for ${target_price}")
        return False
    print(f"  USA price point: {base_pp_id} (customerPrice={actual})")

    cleared = clear_existing_prices(sub_id)
    print(f"  Cleared {cleared} existing price rows")

    # Write the USA price first so ASC knows the base.
    ok, err = set_price_for_territory(sub_id, base_pp_id)
    if not ok:
        print(f"  ! failed to set USA price: {err}")
        return False
    print(f"  ✓ USA price set")

    # Pull equalized USA-equivalent price points for every other territory.
    equalized = get_equalized_price_points(base_pp_id)
    print(f"  {len(equalized)} equalized territories to apply")

    created = 0
    failed = 0
    for i, pp in enumerate(equalized, 1):
        pp_id = pp["id"]
        territory = pp["attributes"].get("territory", "???")
        if territory == BASE_TERRITORY:
            continue  # already set above
        ok, err = set_price_for_territory(sub_id, pp_id)
        if ok:
            created += 1
        else:
            failed += 1
            if failed <= 5:
                print(f"    ! {territory}: {err}")
        if i % 40 == 0:
            print(f"    progress: {i}/{len(equalized)} ({created} ok, {failed} failed)")
            time.sleep(0.4)

    print(f"  ✓ {created} territories priced ({failed} failed)")
    return True


def ensure_free_trial(sub_id, label):
    """Attach a 7-day free-trial intro offer if one doesn't exist already."""
    step(f"{label}: 7-day free trial")

    s, data = asc.get(
        f"/subscriptions/{sub_id}/introductoryOffers?limit=200"
    )
    if s == 200:
        for offer in data.get("data", []):
            attrs = offer["attributes"]
            if (
                attrs.get("offerMode") == "FREE_TRIAL"
                and attrs.get("duration") == "ONE_WEEK"
            ):
                print(f"  ✓ already exists: {offer['id']}")
                return True

    payload = {
        "data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {
                "offerMode": "FREE_TRIAL",
                "duration": "ONE_WEEK",
                "numberOfPeriods": 1,
            },
            "relationships": {
                "subscription": {
                    "data": {"type": "subscriptions", "id": sub_id}
                }
            },
        }
    }
    s, resp = asc.post("/subscriptionIntroductoryOffers", payload)
    if s in (200, 201):
        print(f"  ✓ created intro offer")
        return True
    print(f"  ! failed ({s}): {json.dumps(resp)[:500]}")
    return False


def main():
    app_id = asc.find_app_id()
    if not app_id:
        print("ERROR: App not found in ASC.")
        sys.exit(1)

    subs = list_subscriptions()
    for product_id, price in TARGETS.items():
        sub = subs.get(product_id)
        if not sub:
            print(f"  ! subscription {product_id} missing in ASC")
            continue
        sub_id = sub["id"]
        label = sub["attributes"].get("name") or product_id

        set_prices(sub_id, price, label)
        ensure_free_trial(sub_id, label)

    step("Lifetime")
    print("  Non-consumable lifetime IAPs cannot be created via the REST API.")
    print("  Create it manually in App Store Connect:")
    print("    Product ID: fitscroll_lifetime")
    print("    Type:       Non-Consumable")
    print("    Price:      $29.99 (USA)")
    print("    Then equalize the price manually in ASC or extend this")
    print("    script once Apple ships a POST /inAppPurchasesV2 endpoint.")

    print("\n✓ Done.")


if __name__ == "__main__":
    main()
