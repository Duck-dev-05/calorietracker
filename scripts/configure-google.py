#!/usr/bin/env python3
"""Build public Google OAuth configuration; no client secrets are used."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parent.parent
CLIENT_PATTERN = re.compile(r"[A-Za-z0-9-]+\.apps\.googleusercontent\.com", re.ASCII)

def configure(config_path, output_path, provided=None):
    if provided is not None:
        validate(provided)
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(json.dumps({"iosClientID": provided}, indent=2) + "\n", encoding="utf-8")
    content = json.loads(config_path.read_text(encoding="utf-8-sig"))
    value = os.environ.get("GOOGLE_IOS_CLIENT_ID") or content.get("iosClientID", "")
    validate(value)
    settings = {
        "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "LSRequiresIPhoneOS": True,
        "GIDClientID": value,
        "UILaunchScreen": {},
    }
    if value:
        settings["CFBundleURLTypes"] = [{"CFBundleURLName": "Google OAuth", "CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [".".join(reversed(value.split(".")))]}]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as output:
        plistlib.dump(settings, output)
    return bool(value)

def validate(value):
    if not isinstance(value, str) or (value and (not CLIENT_PATTERN.fullmatch(value) or "YOUR_" in value.upper())):
        raise ValueError("Provide a real iOS OAuth client ID ending in .apps.googleusercontent.com, or leave it empty for an unconfigured build.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client-id", help="Save your public iOS OAuth client ID in the config file")
    parser.add_argument("--config", type=Path, default=ROOT / "Config/GoogleSignIn.json")
    parser.add_argument("--output", type=Path, default=ROOT / "Config/GoogleInfo.generated.plist")
    args = parser.parse_args()
    try:
        ready = configure(args.config, args.output, args.client_id)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Google OAuth configuration failed: {error}\n")
    print("Google OAuth client ID and callback configured." if ready else "Google OAuth is unconfigured: add an iOS client ID to enable the Google button.")
