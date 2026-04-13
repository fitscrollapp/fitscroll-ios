#!/usr/bin/env python3
"""Push everything except screenshots to App Store Connect:

  1. Age rating declaration (clean — no mature content)
  2. Primary + secondary category
  3. Copyright
  4. App Review Details (contact info, demo account, notes)
"""

import json
import sys

import asc_client as asc


LOCALE = "en-US"

# --- Category settings ----------------------------------------------------

PRIMARY_CATEGORY = "HEALTH_AND_FITNESS"
SECONDARY_CATEGORY = "PRODUCTIVITY"

# --- Copyright ------------------------------------------------------------

COPYRIGHT = "© 2026 Hüseyin Babal"

# --- Age rating (all clean — FitScroll has no mature content) -------------

AGE_RATING_ATTRS = {
    # Boolean flags
    "advertising": False,
    "gambling": False,
    "lootBox": False,
    "messagingAndChat": False,
    "parentalControls": False,
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "healthOrWellnessTopics": False,
    # Frequency enums (NONE / INFREQUENT_OR_MILD / FREQUENT_OR_INTENSE)
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    # Override fields
    "ageRatingOverride": "NONE",
    "koreaAgeRatingOverride": "NONE",
    "ageAssurance": False,
}

# --- App Review Information ------------------------------------------------

REVIEW_CONTACT_FIRST = "Huseyin"
REVIEW_CONTACT_LAST = "Babal"
REVIEW_CONTACT_EMAIL = "huseyinbabal@users.noreply.github.com"
REVIEW_CONTACT_PHONE = "+90 555 000 0000"
REVIEW_DEMO_ACCOUNT_REQUIRED = False
REVIEW_NOTES = (
    "FitScroll locks social apps via Screen Time and unlocks them when the user "
    "completes an on-device push-up or squat session tracked by the camera. To "
    "test:\n"
    "1. Finish the short onboarding (swipe through 3 pages, then grant Screen "
    "Time and Camera permissions — both are required for the core experience).\n"
    "2. Subscribe via RevenueCat sandbox — a 7-day free trial is available on "
    "the monthly and yearly plans.\n"
    "3. From the Dashboard, tap the app selection icon (top right), pick any "
    "apps to restrict (Instagram, TikTok, etc.) and set a daily limit.\n"
    "4. Tap the Unlock button and choose Push-up or Squat. Face the camera — "
    "the live pose overlay will count reps. Each rep earns screen time.\n"
    "5. Finish the session to apply the earned minutes; restricted apps will "
    "unlock temporarily.\n\n"
    "All pose detection runs on-device via Apple Vision. No video is recorded "
    "or transmitted. All subscription state is managed by RevenueCat."
)


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def main():
    app_id = asc.find_app_id()
    if not app_id:
        print("ERROR: App not in ASC.")
        sys.exit(1)

    version = asc.find_editable_version(app_id)
    if not version:
        print("ERROR: no editable version.")
        sys.exit(1)

    info_id, _ = asc.find_app_info_localization(app_id, LOCALE)
    if not info_id:
        print("ERROR: no editable appInfo.")
        sys.exit(1)

    print(f"App: {app_id}")
    print(f"Version: {version['id']} ({version['versionString']})")
    print(f"App Info: {info_id}")

    # --- 1. Age rating ----------------------------------------------------
    step("1. Age rating declaration")
    age_status, age_resp = asc.patch(
        f"/ageRatingDeclarations/{info_id}",
        {
            "data": {
                "type": "ageRatingDeclarations",
                "id": info_id,
                "attributes": AGE_RATING_ATTRS,
            }
        },
    )
    print(f"  Status: {age_status}")
    if age_status != 200:
        print(f"  Error: {json.dumps(age_resp, indent=2)[:1500]}")

    # --- 2. Primary / secondary category ----------------------------------
    step("2. Category assignment")
    cat_status, cat_resp = asc.patch(
        f"/appInfos/{info_id}",
        {
            "data": {
                "type": "appInfos",
                "id": info_id,
                "relationships": {
                    "primaryCategory": {
                        "data": {"type": "appCategories", "id": PRIMARY_CATEGORY}
                    },
                    "secondaryCategory": {
                        "data": {"type": "appCategories", "id": SECONDARY_CATEGORY}
                    },
                },
            }
        },
    )
    print(f"  Status: {cat_status}")
    print(f"  Primary: {PRIMARY_CATEGORY}")
    print(f"  Secondary: {SECONDARY_CATEGORY}")
    if cat_status != 200:
        print(f"  Error: {json.dumps(cat_resp, indent=2)[:1500]}")

    # --- 3. Copyright -----------------------------------------------------
    step("3. Copyright")
    cr_status, cr_resp = asc.patch(
        f"/appStoreVersions/{version['id']}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version["id"],
                "attributes": {"copyright": COPYRIGHT},
            }
        },
    )
    print(f"  Status: {cr_status}")
    print(f"  Copyright: {COPYRIGHT}")
    if cr_status != 200:
        print(f"  Error: {json.dumps(cr_resp, indent=2)[:1500]}")

    # --- 4. App Review Details --------------------------------------------
    step("4. App Review information")
    # First check if a review detail already exists
    existing = None
    s, data = asc.get(f"/appStoreVersions/{version['id']}/appStoreReviewDetail")
    if s == 200 and data.get("data"):
        existing = data["data"]["id"]
        print(f"  Found existing review detail: {existing}")

    review_attrs = {
        "contactFirstName": REVIEW_CONTACT_FIRST,
        "contactLastName": REVIEW_CONTACT_LAST,
        "contactEmail": REVIEW_CONTACT_EMAIL,
        "contactPhone": REVIEW_CONTACT_PHONE,
        "demoAccountRequired": REVIEW_DEMO_ACCOUNT_REQUIRED,
        "notes": REVIEW_NOTES,
    }

    if existing:
        rv_status, rv_resp = asc.patch(
            f"/appStoreReviewDetails/{existing}",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": existing,
                    "attributes": review_attrs,
                }
            },
        )
    else:
        rv_status, rv_resp = asc.post(
            "/appStoreReviewDetails",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": review_attrs,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": version["id"],
                            }
                        }
                    },
                }
            },
        )
    print(f"  Status: {rv_status}")
    if rv_status not in (200, 201):
        print(f"  Error: {json.dumps(rv_resp, indent=2)[:1500]}")

    print("\n✓ Done.")


if __name__ == "__main__":
    main()
