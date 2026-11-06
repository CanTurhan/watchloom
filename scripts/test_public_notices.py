#!/usr/bin/env python3
"""Validate preserved license text and consistent public privacy disclosures."""
from html.parser import HTMLParser
import importlib.util
import json
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f'scripts/{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PreText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inside = False
        self.current = ''
        self.notices = []
        self.scripts = 0

    def handle_starttag(self, tag, attrs):
        if tag == 'pre':
            self.inside, self.current = True, ''
        if tag == 'script':
            self.scripts += 1

    def handle_data(self, data):
        if self.inside:
            self.current += data

    def handle_endtag(self, tag):
        if tag == 'pre':
            self.notices.append(self.current)
            self.inside = False


class PublicNoticeTests(unittest.TestCase):
    def test_native_notices_are_complete_on_web_and_remain_bundled(self):
        parser = PreText()
        parser.feed((ROOT / 'docs/licenses.html').read_text())
        self.assertEqual(parser.scripts, 0)
        native = json.loads((ROOT / 'assets/legal/ios_licenses.json').read_text())
        self.assertTrue(native)
        for record in native:
            self.assertIn(record['text'], parser.notices, record['name'])
        self.assertIn('assets/legal/ios_licenses.json', (ROOT / 'pubspec.yaml').read_text())
        self.assertIn('LicenseRegistry.addLicense', (ROOT / 'lib/core/legal/native_licenses.dart').read_text())

    def test_license_html_escapes_markup_without_altering_original_text(self):
        text = 'Copyright A&B\n</pre><script>alert("x")</script>\nAll rights reserved.'
        page = load('sync_web_licenses').render([{'name': '<name>', 'version': '1', 'text': text}])
        parser = PreText()
        parser.feed(page)
        self.assertEqual(parser.notices, [text])
        self.assertEqual(parser.scripts, 0)

    def test_public_community_disclosures_match_in_app_copy_and_are_stable(self):
        generated = load('sync_community_notices').generated(ROOT)
        for path, text in generated.items():
            self.assertEqual(path.read_text(), text, path.name)
        again = load('sync_community_notices').generated(ROOT)
        self.assertEqual(again, generated)
        for name in ['privacy.html', 'terms.html', 'community.html']:
            page = (ROOT / 'docs' / name).read_text()
            self.assertIn('moderator', page.lower())
            self.assertIn('can.turhan.web@gmail.com', page)

    def test_app_owned_account_and_comment_collection_is_declared(self):
        manifest = plistlib.loads((ROOT / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
        types = {entry['NSPrivacyCollectedDataType']: entry for entry in manifest['NSPrivacyCollectedDataTypes']}
        for kind in ['Name', 'EmailAddress', 'UserID', 'OtherUserContent']:
            entry = types[f'NSPrivacyCollectedDataType{kind}']
            self.assertTrue(entry['NSPrivacyCollectedDataTypeLinked'])
            self.assertFalse(entry['NSPrivacyCollectedDataTypeTracking'])
            self.assertEqual(entry['NSPrivacyCollectedDataTypePurposes'], ['NSPrivacyCollectedDataTypePurposeAppFunctionality'])
        self.assertEqual(manifest['NSPrivacyTrackingDomains'], [])


if __name__ == '__main__':
    unittest.main()
