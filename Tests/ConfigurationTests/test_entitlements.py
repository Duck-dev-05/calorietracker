import importlib.util
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("verify_entitlements", ROOT / "scripts/verify-entitlements.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class KeychainEntitlementTests(unittest.TestCase):
    def setUp(self):
        self.values = plistlib.loads((ROOT / "CalorieTracker/CalorieTracker.entitlements").read_bytes())

    def test_source_uses_only_stable_app_scoped_entitlements(self):
        module.verify(self.values, "com.personal.CalorieTracker")

    def test_missing_identity_and_keychain_are_rejected(self):
        for key in ["application-identifier", "com.apple.developer.team-identifier", "keychain-access-groups"]:
            values = dict(self.values)
            del values[key]
            with self.assertRaises(ValueError):
                module.verify(values, "com.personal.CalorieTracker")

    def test_wildcard_and_unrelated_keychain_grants_are_rejected(self):
        for groups in [["*"], ["TROLLTROLL.*"], ["com.apple.token"], self.values["keychain-access-groups"] + ["another.app"]]:
            values = dict(self.values, **{"keychain-access-groups": groups})
            with self.assertRaises(ValueError):
                module.verify(values, "com.personal.CalorieTracker")

    def test_identity_must_match_bundle_and_group(self):
        values = dict(self.values, **{"application-identifier": "TROLLTROLL.another.app"})
        with self.assertRaises(ValueError):
            module.verify(values, "com.personal.CalorieTracker")

    def test_health_and_no_extra_debug_privileges(self):
        for values in [dict(self.values, **{"com.apple.developer.healthkit": False}), dict(self.values, **{"get-task-allow": True})]:
            with self.assertRaises(ValueError):
                module.verify(values, "com.personal.CalorieTracker")
