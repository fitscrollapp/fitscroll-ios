#!/usr/bin/env python3
"""Fill in subscription localization metadata for fitscroll_monthly and
fitscroll_yearly. Without this, the products stay in MISSING_METADATA state
and can't be submitted with the app version.

Locales covered: en-US, tr.
"""

import json
import sys

import asc_client as asc


SUBS = {
    "fitscroll_monthly": "6762101284",
    "fitscroll_yearly": "6762101120",
}

LOCALIZATIONS = {
    "fitscroll_monthly": {
        "en-US": {
            "name": "Monthly Premium",
            "description": (
                "Unlock FitScroll for one month. Lock distracting apps and "
                "earn screen time with every push-up and squat. Includes a "
                "7-day free trial."
            ),
        },
        "tr": {
            "name": "Aylık Premium",
            "description": (
                "FitScroll'u bir ay boyunca aç. Dikkat dağıtıcı uygulamaları "
                "kilitle, her şınav ve squatla ekran süresi kazan. 7 gün "
                "ücretsiz deneme dahil."
            ),
        },
    },
    "fitscroll_yearly": {
        "en-US": {
            "name": "Yearly Premium",
            "description": (
                "Unlock FitScroll for a full year and save. Lock distracting "
                "apps and earn screen time with every push-up and squat. "
                "Includes a 7-day free trial."
            ),
        },
        "tr": {
            "name": "Yıllık Premium",
            "description": (
                "FitScroll'u bir yıl boyunca kullan ve tasarruf et. Dikkat "
                "dağıtıcı uygulamaları kilitle, her şınav ve squatla ekran "
                "süresi kazan. 7 gün ücretsiz deneme dahil."
            ),
        },
    },
}


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def existing_localizations(sub_id):
    """Return dict locale -> localization record id."""
    s, data = asc.get(
        f"/subscriptions/{sub_id}/subscriptionLocalizations?limit=50"
    )
    if s != 200:
        print(f"  ! GET localizations -> {s}: {json.dumps(data)[:400]}")
        return {}
    result = {}
    for loc in data.get("data", []):
        locale = loc["attributes"].get("locale")
        if locale:
            result[locale] = loc["id"]
    return result


def upsert_localization(sub_id, locale, name, description):
    existing = existing_localizations(sub_id)
    if locale in existing:
        loc_id = existing[locale]
        payload = {
            "data": {
                "type": "subscriptionLocalizations",
                "id": loc_id,
                "attributes": {
                    "name": name,
                    "description": description,
                },
            }
        }
        s, resp = asc.patch(f"/subscriptionLocalizations/{loc_id}", payload)
        if s == 200:
            print(f"    ✓ {locale} updated")
            return True
    else:
        payload = {
            "data": {
                "type": "subscriptionLocalizations",
                "attributes": {
                    "locale": locale,
                    "name": name,
                    "description": description,
                },
                "relationships": {
                    "subscription": {
                        "data": {"type": "subscriptions", "id": sub_id}
                    }
                },
            }
        }
        s, resp = asc.post("/subscriptionLocalizations", payload)
        if s in (200, 201):
            print(f"    ✓ {locale} created")
            return True

    print(f"    ! {locale} failed: {json.dumps(resp)[:500]}")
    return False


def main():
    for product_id, sub_id in SUBS.items():
        step(f"{product_id} ({sub_id})")
        for locale, texts in LOCALIZATIONS[product_id].items():
            upsert_localization(
                sub_id,
                locale,
                texts["name"],
                texts["description"],
            )

        # Re-check state
        s, data = asc.get(f"/subscriptions/{sub_id}")
        if s == 200:
            state = data["data"]["attributes"].get("state")
            print(f"  state: {state}")

    print("\n✓ Done.")


if __name__ == "__main__":
    main()
