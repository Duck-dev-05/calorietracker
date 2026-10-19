import importlib.util
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("configure_google", ROOT / "scripts/configure-google.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class GoogleBuildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.config = Path(self.directory.name) / "config.json"
        self.output = Path(self.directory.name) / "Info.plist"
        self.config.write_text('{"iosClientID":""}')
        self.env = patch.dict(os.environ, {"GOOGLE_IOS_CLIENT_ID": ""})
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_missing_client_does_not_invent_credentials_or_callback(self):
        self.assertFalse(module.configure(self.config, self.output))
        data = plistlib.loads(self.output.read_bytes())
        self.assertEqual(data["GIDClientID"], "")
        self.assertNotIn("CFBundleURLTypes", data)

    def test_real_format_creates_matching_reversed_scheme(self):
        value = "123456-test.apps.googleusercontent.com"  # Test fixture only.
        self.assertTrue(module.configure(self.config, self.output, value))
        data = plistlib.loads(self.output.read_bytes())
        self.assertEqual(data["GIDClientID"], value)
        self.assertEqual(data["CFBundleURLTypes"][0]["CFBundleURLSchemes"], ["com.googleusercontent.apps.123456-test"])
        self.assertEqual(data["CFBundleIdentifier"], "$(PRODUCT_BUNDLE_IDENTIFIER)")

    def test_ci_environment_overrides_local_file(self):
        os.environ["GOOGLE_IOS_CLIENT_ID"] = "123456-ci.apps.googleusercontent.com"
        self.assertTrue(module.configure(self.config, self.output))
        self.assertEqual(plistlib.loads(self.output.read_bytes())["GIDClientID"], os.environ["GOOGLE_IOS_CLIENT_ID"])

    def test_invalid_input_does_not_overwrite_existing_configuration(self):
        self.output.write_bytes(b"original")
        for value in ["YOUR_CLIENT_ID", "https://example.test", "abc.apps.googleusercontent.com\n", "bad;value.apps.googleusercontent.com"]:
            with self.assertRaises(ValueError):
                module.configure(self.config, self.output, value)
            self.assertEqual(self.output.read_bytes(), b"original")
            self.assertEqual(self.config.read_text(), '{"iosClientID":""}')

    def test_invalid_environment_fails_instead_of_silent_fallback(self):
        os.environ["GOOGLE_IOS_CLIENT_ID"] = "not-a-client"
        with self.assertRaises(ValueError):
            module.configure(self.config, self.output)
        self.assertFalse(self.output.exists())
