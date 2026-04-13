#!/usr/bin/env python3
"""Update FitScroll App Store version + app info metadata.

Usage:
    python3 update_metadata.py

Requires the app to already exist in App Store Connect (ASC API cannot
create apps; create it manually at appstoreconnect.apple.com first).
"""

import json
import sys

import asc_client as asc


APP_NAME = "FitScroll"
BUNDLE_ID = "com.huseyinbabal.fitscroll"
LOCALE = "en-US"

SUBTITLE = "Exercise to Unlock Apps"

DESCRIPTION = """Tired of doomscrolling until midnight? Losing hours to Instagram, TikTok, and X without remembering what you even saw? FitScroll turns your phone into a workout coach — lock the apps that fuel your doomscroll spiral, and earn screen time back by doing real exercises in front of your camera.

HOW IT WORKS

1. Pick the apps you want to limit — Instagram, TikTok, YouTube, X, or any other time-sink.
2. Set a daily limit. When you hit it, the apps lock automatically.
3. When you want more screen time, open FitScroll and start an exercise session.
4. Your iPhone camera counts your reps in real time using on-device motion detection.
5. Each rep earns minutes of screen time — enough to check your feed, and then back to your day.

KEY FEATURES

• On-Device Rep Counting — Your phone's camera tracks your movements and counts push-ups and squats automatically. Nothing is recorded, nothing leaves your device.

• Screen Time Lock & Unlock — Powered by Apple's Family Controls. Lock any app on your phone and unlock it temporarily by completing a workout.

• Live Pose Overlay — See your skeleton tracked in real time as you exercise, so you know the app is counting every rep.

• Earnable Minutes — Customize how much screen time each rep is worth. Make it easy or brutal — it's up to you.

• Woman & Man Avatars — Switch between animated characters that mirror your position live while you work out.

• Workout History & Analytics — See your reps, minutes earned, and activity charts by day, week, or month.

• Private by Design — All pose detection happens on-device via Apple's Vision framework. No account, no cloud, no tracking.

• Coin Sound + Haptics — Every rep hits with a satisfying "tink" and vibration so you feel the progress.

Built for the person who knows doomscrolling is the problem but can't quite stop. Earn your scrolls with sweat. Break the dopamine loop. Take your attention back.

7 days free, then subscribe monthly or yearly — or unlock everything forever with a one-time Lifetime purchase."""

KEYWORDS = "doomscroll,screen time,pushup,squat,instagram,tiktok,fitness,workout,habit,focus,dopamine"

PROMOTIONAL_TEXT = "Stop doomscrolling. Lock Instagram, TikTok & YouTube until you earn them with push-ups or squats. Live rep counting, 100% on-device. 7-day free trial."

# whatsNew is only editable for version updates (not initial 1.0 release).
# We'll populate it on the next version.
WHATS_NEW = None

PRIVACY_POLICY_URL = "https://huseyinbabal.github.io/fitscroll/privacy"


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def main():
    step("1. Resolving FitScroll app in App Store Connect")
    app_id = asc.find_app_id(BUNDLE_ID)
    if not app_id:
        print(f"  ERROR: No app found with bundle id {BUNDLE_ID!r}.")
        print("  Create the app at https://appstoreconnect.apple.com/ first.")
        sys.exit(1)
    print(f"  app_id = {app_id}")

    step("2. Finding editable app store version")
    version = asc.find_editable_version(app_id)
    if not version:
        print("  ERROR: No editable version found. Create a new version in ASC first.")
        sys.exit(1)
    print(f"  version_id = {version['id']} ({version['versionString']}, {version['state']})")

    step("3. Finding en-US version localization")
    loc_id = asc.find_version_localization(version["id"], LOCALE)
    if not loc_id:
        print(f"  ERROR: No {LOCALE} localization on version {version['id']}.")
        sys.exit(1)
    print(f"  localization_id = {loc_id}")

    step("4. Updating description, keywords, promotional text, what's new")
    attributes = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMOTIONAL_TEXT,
    }
    if WHATS_NEW:
        attributes["whatsNew"] = WHATS_NEW

    # Sanity check the keyword length (Apple enforces ≤ 100 chars).
    if len(KEYWORDS) > 100:
        print(f"  WARN: keywords are {len(KEYWORDS)} chars, will be rejected (max 100)")

    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": loc_id,
            "attributes": attributes,
        }
    }
    status, resp = asc.patch(f"/appStoreVersionLocalizations/{loc_id}", payload)
    print(f"  Status: {status}")
    if status == 200:
        attrs = resp["data"]["attributes"]
        print(f"    description length: {len(attrs.get('description') or '')}")
        print(f"    keywords: {attrs.get('keywords')}")
    else:
        print(f"  Error: {json.dumps(resp, indent=2)[:2000]}")

    step("5. Updating app info localization (subtitle + privacy URL)")
    info_id, info_loc_id = asc.find_app_info_localization(app_id, LOCALE)
    if not info_loc_id:
        print("  WARN: No editable appInfoLocalization found — skipping subtitle update.")
    else:
        print(f"  info_id = {info_id}, info_loc_id = {info_loc_id}")
        info_payload = {
            "data": {
                "type": "appInfoLocalizations",
                "id": info_loc_id,
                "attributes": {
                    "subtitle": SUBTITLE,
                    "privacyPolicyUrl": PRIVACY_POLICY_URL,
                },
            }
        }
        status, resp = asc.patch(f"/appInfoLocalizations/{info_loc_id}", info_payload)
        print(f"  Status: {status}")
        if status != 200:
            print(f"  Error: {json.dumps(resp, indent=2)[:2000]}")

    print("\n✓ Done.")


if __name__ == "__main__":
    main()
