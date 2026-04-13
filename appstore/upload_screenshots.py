#!/usr/bin/env python3
"""Upload FitScroll App Store screenshots.

Expects 6.7" (iPhone 16/17 Pro Max) screenshots in /tmp/fitscroll_screenshots
named 01_*.png, 02_*.png, … in display order.

Target resolution: 1290 × 2796 or 1320 × 2868.
"""

import hashlib
import json
import os
import sys
import time
import urllib.request

import asc_client as asc


LOCALE = "en-US"
DISPLAY_TYPE = "APP_IPHONE_67"  # iPhone 6.7" (Pro Max)
SCREENSHOT_DIR = "/tmp/fitscroll_screenshots"


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def main():
    step("1. Locate FitScroll version localization")
    app_id = asc.find_app_id()
    if not app_id:
        print("  ERROR: App not in App Store Connect yet.")
        sys.exit(1)

    version = asc.find_editable_version(app_id)
    if not version:
        print("  ERROR: No editable version.")
        sys.exit(1)

    loc_id = asc.find_version_localization(version["id"], LOCALE)
    if not loc_id:
        print(f"  ERROR: No {LOCALE} localization.")
        sys.exit(1)
    print(f"  localization_id = {loc_id}")

    step("2. Collect local screenshots")
    if not os.path.isdir(SCREENSHOT_DIR):
        print(f"  ERROR: {SCREENSHOT_DIR} does not exist.")
        print("  Drop your 1290x2796 or 1320x2868 PNGs there first.")
        sys.exit(1)

    files = sorted(
        f for f in os.listdir(SCREENSHOT_DIR)
        if f.lower().endswith(".png")
    )
    if not files:
        print("  ERROR: no PNG screenshots found.")
        sys.exit(1)
    for f in files:
        print(f"    {f}")

    step("3. Resolve (or create) screenshot set for iPhone 6.7")
    status, data = asc.get(
        f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets"
    )
    screenshot_set_id = None
    for s in data.get("data", []):
        if s["attributes"].get("screenshotDisplayType") == DISPLAY_TYPE:
            screenshot_set_id = s["id"]
            break

    if screenshot_set_id:
        print(f"  Reusing existing set {screenshot_set_id}")
        # Delete existing screenshots to re-upload fresh
        status, data = asc.get(f"/appScreenshotSets/{screenshot_set_id}/appScreenshots")
        for ss in data.get("data", []):
            st, _ = asc.delete(f"/appScreenshots/{ss['id']}")
            print(f"    deleted {ss['id']}: {st}")
    else:
        print("  Creating new screenshot set")
        status, resp = asc.post("/appScreenshotSets", {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                    }
                },
            }
        })
        if status not in (200, 201):
            print(f"  Error: {json.dumps(resp, indent=2)[:1000]}")
            sys.exit(1)
        screenshot_set_id = resp["data"]["id"]
        print(f"  Created set {screenshot_set_id}")

    step("4. Upload each screenshot")
    for i, name in enumerate(files, 1):
        path = os.path.join(SCREENSHOT_DIR, name)
        with open(path, "rb") as f:
            data_bytes = f.read()

        size = len(data_bytes)
        md5 = hashlib.md5(data_bytes).hexdigest()
        print(f"\n  [{i}/{len(files)}] {name} ({size} bytes, md5={md5[:8]}…)")

        # 4a: reservation
        status, resp = asc.post("/appScreenshots", {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": name, "fileSize": size},
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": screenshot_set_id}
                    }
                },
            }
        })
        if status not in (200, 201):
            print(f"    Error creating reservation: {json.dumps(resp, indent=2)[:800]}")
            continue

        screenshot_id = resp["data"]["id"]
        upload_ops = resp["data"]["attributes"]["uploadOperations"]

        # 4b: PUT chunks
        ok = True
        for j, op in enumerate(upload_ops, 1):
            chunk = data_bytes[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            req = urllib.request.Request(op["url"], data=chunk, method="PUT", headers=headers)
            try:
                with urllib.request.urlopen(req) as resp2:
                    print(f"    part {j}: {resp2.status}")
            except Exception as e:
                print(f"    part {j} failed: {e}")
                ok = False
                break

        if not ok:
            continue

        # 4c: commit
        status, resp = asc.patch(f"/appScreenshots/{screenshot_id}", {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": md5},
            }
        })
        if status == 200:
            state = resp["data"]["attributes"].get("assetDeliveryState", {}).get("state")
            print(f"    ✓ committed ({state})")
        else:
            print(f"    commit failed: {json.dumps(resp, indent=2)[:800]}")

        time.sleep(0.5)

    step("5. Verify")
    status, data = asc.get(f"/appScreenshotSets/{screenshot_set_id}/appScreenshots")
    for ss in data.get("data", []):
        attrs = ss["attributes"]
        state = attrs.get("assetDeliveryState", {}).get("state")
        print(f"    {attrs.get('fileName')}: {state}")

    print("\n✓ Done.")


if __name__ == "__main__":
    main()
