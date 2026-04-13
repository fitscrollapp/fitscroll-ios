"""Shared App Store Connect API helpers for FitScroll metadata scripts."""

import json
import time
import urllib.parse
import urllib.request

import jwt


# --- App Store Connect credentials ----------------------------------------
# Same key used across personal projects. The .p8 file is stored in Downloads.

KEY_ID = "7M8BJCJ9J5"
ISSUER_ID = "3f8e0f36-6b6c-46f1-8160-197335770eeb"
KEY_FILE = "/Users/huseyinbabal/Downloads/AuthKey_7M8BJCJ9J5.p8"

BUNDLE_ID = "com.huseyinbabal.fitscroll"

BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def generate_token() -> str:
    """Build a short-lived ES256 JWT for the ASC REST API."""
    with open(KEY_FILE, "r") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": KEY_ID, "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api_headers() -> dict:
    return {
        "Authorization": f"Bearer {generate_token()}",
        "Content-Type": "application/json",
    }


def _request(method: str, path: str, body=None):
    url = f"{BASE_URL}{path}" if path.startswith("/") else path
    data = None
    if body is not None:
        data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method, headers=api_headers())
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode(errors="replace")}


def get(path: str):
    return _request("GET", path)


def post(path: str, body: dict):
    return _request("POST", path, body)


def patch(path: str, body: dict):
    return _request("PATCH", path, body)


def delete(path: str):
    return _request("DELETE", path)


# --- High-level lookups ---------------------------------------------------

def find_app_id(bundle_id: str = BUNDLE_ID) -> str | None:
    """Returns the ASC appId for the given bundle id, or None if not found."""
    status, data = get(f"/apps?filter[bundleId]={urllib.parse.quote(bundle_id)}")
    if status != 200:
        return None
    items = data.get("data", [])
    return items[0]["id"] if items else None


def find_editable_version(app_id: str, platform: str = "IOS") -> dict | None:
    """Find the most recent editable app store version.

    Returns a dict with 'id' and 'versionString' or None.
    """
    status, data = get(
        f"/apps/{app_id}/appStoreVersions?filter[platform]={platform}&limit=10"
    )
    if status != 200:
        return None
    for v in data.get("data", []):
        state = v["attributes"].get("appStoreState") or v["attributes"].get("state")
        if state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                     "REJECTED", "METADATA_REJECTED", "READY_FOR_SALE",
                     "PENDING_DEVELOPER_RELEASE", "WAITING_FOR_REVIEW",
                     "IN_REVIEW"):
            return {
                "id": v["id"],
                "versionString": v["attributes"].get("versionString"),
                "state": state,
            }
    return None


def find_version_localization(version_id: str, locale: str = "en-US") -> str | None:
    """Find the localization record for a given version and locale."""
    status, data = get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    if status != 200:
        return None
    for loc in data.get("data", []):
        if loc["attributes"].get("locale") == locale:
            return loc["id"]
    return None


def find_app_info_localization(app_id: str, locale: str = "en-US") -> tuple[str | None, str | None]:
    """Returns (appInfoId, localizationId) for the EDITABLE app info record."""
    status, data = get(f"/apps/{app_id}/appInfos")
    if status != 200:
        return None, None

    for info in data.get("data", []):
        info_id = info["id"]
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        # Pick an editable appInfo (not READY_FOR_SALE/locked).
        if state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                     "REJECTED", "METADATA_REJECTED", None):
            loc_status, loc_data = get(f"/appInfos/{info_id}/appInfoLocalizations")
            if loc_status == 200:
                for loc in loc_data.get("data", []):
                    if loc["attributes"].get("locale") == locale:
                        return info_id, loc["id"]
    return None, None
