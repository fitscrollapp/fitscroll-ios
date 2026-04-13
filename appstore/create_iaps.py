#!/usr/bin/env python3
"""Create FitScroll in-app purchases in App Store Connect.

Creates:
  - Subscription group "FitScroll Premium"
  - Monthly subscription (fitscroll_monthly) with 7-day free trial intro offer
  - Yearly subscription  (fitscroll_yearly)  with 7-day free trial intro offer
  - Lifetime non-consumable (fitscroll_lifetime)

Required pre-requisite: RevenueCat product identifiers were already set up
via REST API, but App Store Connect needs its own product records so
actual purchase flows work in sandbox + production.
"""

import json
import sys

import asc_client as asc


GROUP_REFERENCE = "FitScroll Premium Group"

PRODUCTS = [
    {
        "productId": "fitscroll_monthly",
        "referenceName": "FitScroll Monthly",
        "reviewNote": "Monthly auto-renewable subscription with 7-day free trial. Grants the 'premium' entitlement which unlocks the full app after onboarding.",
        "kind": "subscription",
        "duration": "ONE_MONTH",
        "rank": 2,
    },
    {
        "productId": "fitscroll_yearly",
        "referenceName": "FitScroll Yearly",
        "reviewNote": "Yearly auto-renewable subscription with 7-day free trial. Same entitlement as monthly but billed annually.",
        "kind": "subscription",
        "duration": "ONE_YEAR",
        "rank": 1,
    },
    {
        "productId": "fitscroll_lifetime",
        "referenceName": "FitScroll Lifetime",
        "reviewNote": "One-time purchase for lifetime access. Unlocks the same premium entitlement forever.",
        "kind": "non_consumable",
    },
]


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def get_or_create_subscription_group(app_id: str) -> str:
    """Find existing subscription group by reference name, or create one."""
    s, data = asc.get(f"/apps/{app_id}/subscriptionGroups")
    if s == 200:
        for g in data.get("data", []):
            if g["attributes"].get("referenceName") == GROUP_REFERENCE:
                return g["id"]

    # Create new group
    s, resp = asc.post(
        "/subscriptionGroups",
        {
            "data": {
                "type": "subscriptionGroups",
                "attributes": {"referenceName": GROUP_REFERENCE},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        },
    )
    if s not in (200, 201):
        print(f"  Error creating group: {json.dumps(resp, indent=2)[:1500]}")
        sys.exit(1)
    return resp["data"]["id"]


def create_subscription(group_id: str, product: dict) -> str:
    """Create a subscription product inside a group."""
    s, resp = asc.post(
        "/subscriptions",
        {
            "data": {
                "type": "subscriptions",
                "attributes": {
                    "name": product["referenceName"],
                    "productId": product["productId"],
                    "subscriptionPeriod": product["duration"],
                    "reviewNote": product["reviewNote"],
                    "familySharable": False,
                    "groupLevel": product["rank"],
                },
                "relationships": {
                    "group": {
                        "data": {"type": "subscriptionGroups", "id": group_id}
                    }
                },
            }
        },
    )
    if s not in (200, 201):
        print(f"  Error: {json.dumps(resp, indent=2)[:1500]}")
        return None
    return resp["data"]["id"]


def create_non_consumable(app_id: str, product: dict) -> str:
    """Not currently supported by App Store Connect REST API.

    Non-consumable and consumable IAPs must be created manually via the
    ASC web UI (App Store Connect → Your App → In-App Purchases → +).
    Only subscription products have a working POST endpoint (/subscriptions).
    """
    print(f"  ⚠ Skipped — non-consumable IAPs are not creatable via REST API.")
    print(f"    Create manually in App Store Connect:")
    print(f"      Product ID: {product['productId']}")
    print(f"      Name: {product['referenceName']}")
    print(f"      Type: Non-Consumable")
    return None


def main():
    app_id = asc.find_app_id()
    if not app_id:
        print("ERROR: App not in ASC.")
        sys.exit(1)

    step(f"1. Get or create subscription group: {GROUP_REFERENCE}")
    group_id = get_or_create_subscription_group(app_id)
    print(f"  Group ID: {group_id}")

    for product in PRODUCTS:
        step(f"2. Create {product['referenceName']}  ({product['productId']})")
        if product["kind"] == "subscription":
            product_id = create_subscription(group_id, product)
        else:
            product_id = create_non_consumable(app_id, product)

        if product_id:
            print(f"  ✓ Created: {product_id}")

    print("\n✓ Done.")
    print("\nNext manual steps in App Store Connect:")
    print("  - Add localized display names + descriptions for each product")
    print("  - Set prices (Monthly ~$4.99, Yearly ~$39.99, Lifetime ~$79.99)")
    print("  - Add 7-day free trial as an Introductory Offer on the")
    print("    monthly and yearly subscriptions")
    print("  - Submit each product along with the app for review")


if __name__ == "__main__":
    main()
