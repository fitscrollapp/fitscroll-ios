#!/usr/bin/env python3
"""Push localized App Store metadata for every locale in appstore/metadata/.

For each metadata/<locale>.json this ensures both an appStoreVersionLocalization
(description / keywords / promotionalText / whatsNew) and an appInfoLocalization
(name / subtitle / privacyPolicyUrl) exist for that locale on the current
editable version, creating them if missing, then PATCHes the translated copy.

Usage:
    python3 push_localized_metadata.py            # all locales
    python3 push_localized_metadata.py es-ES ja   # only these locales
"""

import glob
import json
import os
import sys

import asc_client as asc

BUNDLE_ID = "com.huseyinbabal.fitscroll"
PRIVACY_POLICY_URL = "https://fit-scroll.app/privacy"
METADATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "metadata")


def step(msg):
    print(f"\n{'='*60}\n  {msg}\n{'='*60}")


def get_version_loc_id(version_id, locale):
    """Return the appStoreVersionLocalization id for locale, creating it if absent."""
    status, data = asc.get(
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200"
    )
    for item in data.get("data", []):
        if item["attributes"].get("locale") == locale:
            return item["id"]
    # Create it.
    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": locale},
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            },
        }
    }
    status, resp = asc.post("/appStoreVersionLocalizations", payload)
    if status not in (200, 201):
        print(f"    ! could not create version loc for {locale}: {status} "
              f"{json.dumps(resp)[:300]}")
        return None
    return resp["data"]["id"]


def get_info_loc_id(app_info_id, locale):
    """Return the appInfoLocalization id for locale, creating it if absent."""
    status, data = asc.get(
        f"/appInfos/{app_info_id}/appInfoLocalizations?limit=200"
    )
    for item in data.get("data", []):
        if item["attributes"].get("locale") == locale:
            return item["id"]
    payload = {
        "data": {
            "type": "appInfoLocalizations",
            "attributes": {"locale": locale},
            "relationships": {
                "appInfo": {"data": {"type": "appInfos", "id": app_info_id}}
            },
        }
    }
    status, resp = asc.post("/appInfoLocalizations", payload)
    if status not in (200, 201):
        print(f"    ! could not create app info loc for {locale}: {status} "
              f"{json.dumps(resp)[:300]}")
        return None
    return resp["data"]["id"]


def main():
    only = set(sys.argv[1:])

    step("Resolving app + editable version")
    app_id = asc.find_app_id(BUNDLE_ID)
    if not app_id:
        sys.exit(f"No app for bundle {BUNDLE_ID!r}")
    # Strictly target the version that is actually editable (in prep), NOT a
    # live READY_FOR_SALE version (asc.find_editable_version is too permissive).
    _, vdata = asc.get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")
    version = None
    for v in vdata.get("data", []):
        state = v["attributes"].get("appStoreState") or v["attributes"].get("state")
        if state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                     "REJECTED", "METADATA_REJECTED"):
            version = {"id": v["id"],
                       "versionString": v["attributes"].get("versionString"),
                       "state": state}
            break
    if not version:
        sys.exit("No editable (PREPARE_FOR_SUBMISSION) version — create 1.0.3 in ASC first.")
    version_id = version["id"]
    print(f"  app={app_id} version={version_id} "
          f"({version['versionString']}, {version['state']})")

    # appInfo id (shared across locales) — discovered via the en-US lookup.
    info_id, _ = asc.find_app_info_localization(app_id, "en-US")
    if not info_id:
        sys.exit("Could not resolve appInfo id.")

    files = sorted(glob.glob(os.path.join(METADATA_DIR, "*.json")))
    for path in files:
        meta = json.load(open(path, encoding="utf-8"))
        locale = meta["locale"]
        if only and locale not in only:
            continue
        step(f"Locale: {locale}")

        if len(meta.get("keywords", "")) > 100:
            print(f"  WARN keywords {len(meta['keywords'])} chars > 100 — will reject")

        # Version localization: description / keywords / promo / whatsNew.
        loc_id = get_version_loc_id(version_id, locale)
        if loc_id:
            attrs = {
                "description": meta["description"],
                "keywords": meta["keywords"],
                "promotionalText": meta["promotionalText"],
            }
            if meta.get("whatsNew"):
                attrs["whatsNew"] = meta["whatsNew"]
            status, resp = asc.patch(
                f"/appStoreVersionLocalizations/{loc_id}",
                {"data": {"type": "appStoreVersionLocalizations", "id": loc_id,
                          "attributes": attrs}},
            )
            print(f"  version loc PATCH {status}"
                  + ("" if status == 200 else f" {json.dumps(resp)[:300]}"))

        # App info localization: name / subtitle / privacy URL.
        info_loc_id = get_info_loc_id(info_id, locale)
        if info_loc_id:
            status, resp = asc.patch(
                f"/appInfoLocalizations/{info_loc_id}",
                {"data": {"type": "appInfoLocalizations", "id": info_loc_id,
                          "attributes": {
                              "name": meta["name"],
                              "subtitle": meta["subtitle"],
                              "privacyPolicyUrl": PRIVACY_POLICY_URL,
                          }}},
            )
            print(f"  app info PATCH {status}"
                  + ("" if status == 200 else f" {json.dumps(resp)[:300]}"))

    print("\n✓ Done pushing localized metadata.")


if __name__ == "__main__":
    main()
