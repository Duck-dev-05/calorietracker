#!/usr/bin/env python3
"""Verify the minimal, app-scoped entitlement set for this TrollStore build."""
import argparse
import plistlib
from pathlib import Path

def verify(values, bundle_id):
    identity = "TROLLTROLL." + bundle_id
    expected = {
        "application-identifier": identity,
        "com.apple.developer.team-identifier": "TROLLTROLL",
        "keychain-access-groups": [identity],
        "com.apple.developer.healthkit": True,
    }
    if values != expected:
        raise ValueError("TrollStore entitlements must contain exactly the app-scoped identity/Keychain group and HealthKit access; missing, broad or unexpected grants are rejected.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("entitlements", type=Path)
    parser.add_argument("--info-plist", required=True, type=Path)
    args = parser.parse_args()
    try:
        with args.info_plist.open("rb") as file:
            bundle_id = plistlib.load(file)["CFBundleIdentifier"]
        if bundle_id != "com.personal.CalorieTracker":
            raise ValueError("Unexpected bundle ID; keep the journal container identity stable.")
        with args.entitlements.open("rb") as file:
            verify(plistlib.load(file), bundle_id)
    except (ValueError, KeyError, OSError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Entitlement verification failed: {error}\n")
    print("Verified Nourish-only Keychain identity and HealthKit entitlements.")
