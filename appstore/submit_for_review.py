#!/usr/bin/env python3
"""Attach the processed build to the editable version and submit for review.

Run AFTER the 1.0.3 / build 21 archive has finished processing in App Store
Connect (processingState VALID). Uses the modern reviewSubmissions flow.

Usage:
    python3 submit_for_review.py [version] [build_number]
Defaults: version=1.0.3, build_number=21
"""

import json
import sys

import asc_client as asc

BUNDLE_ID = "com.huseyinbabal.fitscroll"
VERSION_STRING = sys.argv[1] if len(sys.argv) > 1 else "1.0.3"
BUILD_NUMBER = sys.argv[2] if len(sys.argv) > 2 else "21"
EDITABLE_STATES = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                   "REJECTED", "METADATA_REJECTED")


def step(m): print(f"\n{'='*60}\n  {m}\n{'='*60}")


def find_version(app_id):
    _, data = asc.get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")
    for v in data.get("data", []):
        st = v["attributes"].get("appStoreState") or v["attributes"].get("state")
        if v["attributes"].get("versionString") == VERSION_STRING and st in EDITABLE_STATES:
            return v["id"], st
    return None, None


def find_build(app_id):
    # Builds for this app + CFBundleVersion, must be processed (VALID).
    _, data = asc.get(
        f"/builds?filter[app]={app_id}&filter[version]={BUILD_NUMBER}"
        f"&include=preReleaseVersion&limit=20"
    )
    for b in data.get("data", []):
        attrs = b["attributes"]
        if attrs.get("processingState") == "VALID":
            return b["id"], attrs.get("version")
    # Fall back: report whatever was found, with state.
    found = [(b["id"], b["attributes"].get("version"),
              b["attributes"].get("processingState")) for b in data.get("data", [])]
    print(f"  builds seen for v{BUILD_NUMBER}: {found}")
    return None, None


def main():
    app_id = asc.find_app_id(BUNDLE_ID)
    if not app_id:
        sys.exit("app not found")

    step(f"1. Locating editable version {VERSION_STRING}")
    version_id, state = find_version(app_id)
    if not version_id:
        sys.exit(f"No editable {VERSION_STRING} version found.")
    print(f"  version_id={version_id} ({state})")

    step(f"2. Locating processed build {BUILD_NUMBER}")
    build_id, _ = find_build(app_id)
    if not build_id:
        sys.exit("No VALID (processed) build found yet — wait for processing and retry.")
    print(f"  build_id={build_id}")

    step("3. Attaching build to version")
    st, resp = asc.patch(
        f"/appStoreVersions/{version_id}",
        {"data": {"type": "appStoreVersions", "id": version_id,
                  "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}},
    )
    print(f"  attach status {st}")
    if st not in (200, 201):
        print(json.dumps(resp)[:600])
        sys.exit("attach failed")

    step("4. Opening / reusing a review submission")
    # Reuse an existing open submission if present, else create one.
    _, subs = asc.get(
        f"/reviewSubmissions?filter[app]={app_id}&filter[platform]=IOS&limit=10"
    )
    sub_id = None
    for s in subs.get("data", []):
        if s["attributes"].get("state") in ("READY_FOR_REVIEW", "WAITING_FOR_REVIEW",
                                            "UNRESOLVED_ISSUES", None):
            if s["attributes"].get("state") == "READY_FOR_REVIEW":
                sub_id = s["id"]
                break
    if not sub_id:
        st, resp = asc.post("/reviewSubmissions", {
            "data": {"type": "reviewSubmissions",
                     "attributes": {"platform": "IOS"},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        if st not in (200, 201):
            print(json.dumps(resp)[:800]); sys.exit("could not create review submission")
        sub_id = resp["data"]["id"]
    print(f"  submission_id={sub_id}")

    step("5. Adding the version as a submission item")
    st, resp = asc.post("/reviewSubmissionItems", {
        "data": {"type": "reviewSubmissionItems",
                 "relationships": {
                     "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                     "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    print(f"  item status {st}")
    if st not in (200, 201):
        # 409 often means the item already exists — keep going to submit.
        print(json.dumps(resp)[:500])

    step("6. Submitting the review submission")
    st, resp = asc.patch(f"/reviewSubmissions/{sub_id}", {
        "data": {"type": "reviewSubmissions", "id": sub_id,
                 "attributes": {"submitted": True}}})
    print(f"  submit status {st}")
    if st in (200, 201):
        print(f"\n✓ Submitted {VERSION_STRING} (build {BUILD_NUMBER}) for App Store review.")
    else:
        print(json.dumps(resp, indent=2)[:1500])


if __name__ == "__main__":
    main()
