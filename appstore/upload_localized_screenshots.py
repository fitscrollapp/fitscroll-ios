#!/usr/bin/env python3
"""Upload localized App Store screenshots for every locale folder.

Reads PNGs from <root>/<folder>/*.png where <folder> is a generator locale
code (en, tr, pt-BR, es, fr, de, it, ja, ko, zh-Hans, ru), maps it to the
App Store Connect locale, and uploads them to that version localization's
iPhone 6.9" (APP_IPHONE_69) screenshot set — replacing any existing shots.

Usage:
    python3 upload_localized_screenshots.py [root] [locale ...]
Defaults: root=screenshots-generator/public/screenshots, all locales found.
Target resolution: 1320 × 2868.
"""

import hashlib
import json
import os
import sys
import time
import urllib.request

import asc_client as asc

DISPLAY_TYPE = "APP_IPHONE_67"  # iPhone 6.9"/6.7" display class (accepts 1320×2868)
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.join(HERE, "screenshots-generator", "public", "screenshots")
EDITABLE_STATES = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                   "REJECTED", "METADATA_REJECTED")

# generator folder code -> App Store Connect locale
FOLDER_TO_ASC = {
    "en": "en-US", "tr": "tr", "pt-BR": "pt-BR", "es": "es-ES", "fr": "fr-FR",
    "de": "de-DE", "it": "it", "ja": "ja", "ko": "ko", "zh-Hans": "zh-Hans", "ru": "ru",
}


def step(m): print(f"\n{'='*60}\n  {m}\n{'='*60}")


def editable_version(app_id):
    _, d = asc.get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")
    for v in d.get("data", []):
        st = v["attributes"].get("appStoreState") or v["attributes"].get("state")
        if st in EDITABLE_STATES:
            return v["id"]
    return None


def loc_id_for(version_id, asc_locale):
    _, d = asc.get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    for l in d.get("data", []):
        if l["attributes"].get("locale") == asc_locale:
            return l["id"]
    return None


def set_id_for(loc_id):
    _, d = asc.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    for s in d.get("data", []):
        if s["attributes"].get("screenshotDisplayType") == DISPLAY_TYPE:
            # wipe existing so we re-upload fresh
            _, ss = asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots")
            for x in ss.get("data", []):
                asc.delete(f"/appScreenshots/{x['id']}")
            return s["id"]
    st, resp = asc.post("/appScreenshotSets", {
        "data": {"type": "appScreenshotSets",
                 "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                 "relationships": {"appStoreVersionLocalization":
                                   {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})
    if st not in (200, 201):
        print("  set create failed:", json.dumps(resp)[:400]); return None
    return resp["data"]["id"]


def upload_one(set_id, path, name):
    data = open(path, "rb").read()
    md5 = hashlib.md5(data).hexdigest()
    st, resp = asc.post("/appScreenshots", {
        "data": {"type": "appScreenshots",
                 "attributes": {"fileName": name, "fileSize": len(data)},
                 "relationships": {"appScreenshotSet":
                                   {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if st not in (200, 201):
        print(f"    reserve fail {name}: {json.dumps(resp)[:300]}"); return False
    sid = resp["data"]["id"]
    for op in resp["data"]["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        req = urllib.request.Request(op["url"], data=chunk, method="PUT", headers=headers)
        try:
            urllib.request.urlopen(req)
        except Exception as e:
            print(f"    PUT fail {name}: {e}"); return False
    st, resp = asc.patch(f"/appScreenshots/{sid}", {
        "data": {"type": "appScreenshots", "id": sid,
                 "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
    ok = st == 200
    print(f"    {'✓' if ok else '✗'} {name}")
    return ok


def main():
    args = sys.argv[1:]
    root = args[0] if args and os.path.isdir(args[0]) else DEFAULT_ROOT
    only = set(a for a in args if a in FOLDER_TO_ASC)

    app_id = asc.find_app_id()
    version_id = editable_version(app_id)
    if not version_id:
        sys.exit("No editable (PREPARE_FOR_SUBMISSION) version found.")
    print(f"app={app_id} version={version_id}")

    folders = sorted(d for d in os.listdir(root)
                     if os.path.isdir(os.path.join(root, d)) and d in FOLDER_TO_ASC)
    for folder in folders:
        if only and folder not in only:
            continue
        asc_locale = FOLDER_TO_ASC[folder]
        files = sorted(f for f in os.listdir(os.path.join(root, folder)) if f.lower().endswith(".png"))
        if not files:
            continue
        step(f"{folder} -> {asc_locale}  ({len(files)} shots)")
        loc_id = loc_id_for(version_id, asc_locale)
        if not loc_id:
            print(f"  no version localization for {asc_locale}; skipping"); continue
        set_id = set_id_for(loc_id)
        if not set_id:
            continue
        for name in files:
            upload_one(set_id, os.path.join(root, folder, name), name)
            time.sleep(0.3)

    print("\n✓ Done uploading localized screenshots.")


if __name__ == "__main__":
    main()
