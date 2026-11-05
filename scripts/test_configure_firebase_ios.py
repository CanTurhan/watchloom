#!/usr/bin/env python3
from pathlib import Path
import contextlib
import io
import plistlib
import tempfile
import unittest
import configure_firebase_ios as module

REAL_ROOT = module.ROOT


def config():
    return dict(PROJECT_ID='watchloom-test-only', GOOGLE_APP_ID='1:123456:ios:abc123',
                API_KEY='public-test-client-key', GCM_SENDER_ID='123456',
                CLIENT_ID='123456-ios.apps.googleusercontent.com',
                REVERSED_CLIENT_ID='com.googleusercontent.apps.123456-ios',
                BUNDLE_ID='com.canturhan.watchloom')


class ConfigTests(unittest.TestCase):
    def test_wrong_application_and_incomplete_google_config_are_rejected(self):
        wrong = config(); wrong['BUNDLE_ID'] = 'com.some.other.app'
        with self.assertRaises(ValueError): module.validate(wrong)
        wrong = config(); del wrong['CLIENT_ID']
        with self.assertRaises(ValueError): module.validate(wrong)
        wrong = config(); wrong['REVERSED_CLIENT_ID'] = 'another-client'
        with self.assertRaises(ValueError): module.validate(wrong)

    def test_configuration_is_idempotent_and_keeps_other_url_schemes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in ['lib', 'ios/Runner', 'ios/Runner.xcodeproj']:
                (root / path).mkdir(parents=True)
            (root / 'ios/Runner.xcodeproj/project.pbxproj').write_text(
                (REAL_ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text())
            (root / 'ios/Runner/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleURLTypes': [{'CFBundleURLName': 'other', 'CFBundleURLSchemes': ['watchloom']}] }))
            module.ROOT = root
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    module.configure(config()); module.configure(config())
                info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
                self.assertEqual(len(info['CFBundleURLTypes']), 2)
                self.assertIn('watchloom', str(info['CFBundleURLTypes']))
                self.assertTrue(info['FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED'])
                project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
                self.assertEqual(project.count('GoogleService-Info.plist in Resources'), 2)
                self.assertIn('watchloom-test-only', (root / 'lib/firebase_options.dart').read_text())
            finally:
                module.ROOT = REAL_ROOT


if __name__ == '__main__': unittest.main()
