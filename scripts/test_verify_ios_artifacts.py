"""Exercise the upload guard with real temporary archive/IPA structures."""

import contextlib
import io
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_ios_artifacts import verify
from check_ios_security import REQUIRED_PODS


class ArtifactChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="watchloom-artifacts-")
        self.addCleanup(self.directory.cleanup)
        self.project = Path(self.directory.name)
        (self.project / "pubspec.yaml").write_text("version: 1.1.0+4\n")
        (self.project / "ios").mkdir()
        (self.project / "ios/Podfile").write_text("platform :ios, '15.0'\n")
        self.archive = self.project / "build/ios/archive/Runner.xcarchive"
        self.app = self.archive / "Products/Applications/Runner.app"
        self.app.mkdir(parents=True)
        self.info = {
            "CFBundleIdentifier": "com.canturhan.watchloom",
            "CFBundleShortVersionString": "1.1.0",
            "CFBundleVersion": "4",
            "MinimumOSVersion": "15.0",
        }
        (self.archive / "Info.plist").write_bytes(
            plistlib.dumps({"ApplicationProperties": self.info})
        )
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))
        for name, version in REQUIRED_PODS.items():
            bundle = self.app / f'{name}_Privacy.bundle'
            bundle.mkdir()
            (bundle / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': version}))
        self.ipa = self.project / "build/ios/ipa/Watchloom.ipa"
        self.ipa.parent.mkdir(parents=True)
        self.write_ipa(self.info)

    def write_ipa(self, info, storekit=False, firebase_versions=None):
        with zipfile.ZipFile(self.ipa, "w") as package:
            package.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(info))
            if storekit:
                package.writestr("Payload/Runner.app/Watchloom.storekit", "{}")
            for name, version in (firebase_versions or REQUIRED_PODS).items():
                package.writestr(f'Payload/Runner.app/{name}_Privacy.bundle/Info.plist',
                                 plistlib.dumps({'CFBundleShortVersionString': version}))

    def test_matching_release_passes(self):
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.project)

    def test_old_archive_cannot_be_uploaded_as_current_build(self):
        stale = dict(self.info, CFBundleVersion="3")
        (self.archive / "Info.plist").write_bytes(
            plistlib.dumps({"ApplicationProperties": stale})
        )
        with self.assertRaisesRegex(ValueError, "Archive: CFBundleVersion"):
            verify(self.project)

    def test_archive_requiring_ios_16_is_rejected(self):
        (self.app / "Info.plist").write_bytes(
            plistlib.dumps(dict(self.info, MinimumOSVersion="16.0"))
        )
        with self.assertRaisesRegex(ValueError, "Archived app: MinimumOSVersion"):
            verify(self.project)

    def test_ipa_must_also_support_ios_15(self):
        self.write_ipa(dict(self.info, MinimumOSVersion="16.0"))
        with self.assertRaisesRegex(ValueError, "IPA: MinimumOSVersion"):
            verify(self.project)

    def test_exported_ipa_cannot_be_a_different_build(self):
        self.write_ipa(dict(self.info, CFBundleVersion="3"))
        with self.assertRaisesRegex(ValueError, "IPA: CFBundleVersion"):
            verify(self.project)

    def test_storekit_test_configuration_is_not_shipped(self):
        self.write_ipa(self.info, storekit=True)
        with self.assertRaisesRegex(ValueError, "local StoreKit test configuration"):
            verify(self.project)

    def test_direct_archive_upload_does_not_consume_an_old_ipa(self):
        self.write_ipa(dict(self.info, CFBundleVersion="3"))
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.project, archive_only=True)
        with self.assertRaisesRegex(ValueError, "Re-export the current archive"):
            verify(self.project)

    def test_direct_archive_upload_needs_no_local_ipa(self):
        self.ipa.unlink()
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.project, archive_only=True)

    def test_direct_upload_still_rejects_old_archive_metadata(self):
        (self.archive / "Info.plist").write_bytes(
            plistlib.dumps({"ApplicationProperties": dict(self.info, CFBundleVersion="3")})
        )
        with self.assertRaisesRegex(ValueError, "Archive: CFBundleVersion"):
            verify(self.project, archive_only=True)

    def test_direct_upload_still_rejects_old_archived_app(self):
        (self.app / "Info.plist").write_bytes(
            plistlib.dumps(dict(self.info, CFBundleVersion="3"))
        )
        with self.assertRaisesRegex(ValueError, "Archived app: CFBundleVersion"):
            verify(self.project, archive_only=True)

    def test_direct_upload_still_rejects_ios_16_archive(self):
        (self.app / "Info.plist").write_bytes(
            plistlib.dumps(dict(self.info, MinimumOSVersion="16.0"))
        )
        with self.assertRaisesRegex(ValueError, "Archived app: MinimumOSVersion"):
            verify(self.project, archive_only=True)

    def test_direct_upload_still_rejects_storekit_test_configuration(self):
        (self.app / "Watchloom.storekit").write_text("{}")
        with self.assertRaisesRegex(ValueError, "local StoreKit test configuration"):
            verify(self.project, archive_only=True)

    def test_direct_upload_rejects_an_archive_using_the_old_firestore_trust_store(self):
        bundle = self.app / 'FirebaseFirestoreInternal_Privacy.bundle/Info.plist'
        bundle.write_bytes(plistlib.dumps({'CFBundleShortVersionString': '12.6.0'}))
        with self.assertRaisesRegex(ValueError, 'Archived app: FirebaseFirestoreInternal must be 12.19.3'):
            verify(self.project, archive_only=True)

    def test_new_archive_does_not_make_an_old_sdk_ipa_uploadable(self):
        self.write_ipa(self.info, firebase_versions=dict(REQUIRED_PODS, FirebaseFirestoreInternal='12.6.0'))
        with self.assertRaisesRegex(ValueError, 'IPA: FirebaseFirestoreInternal must be 12.19.3'):
            verify(self.project)

    def test_missing_sdk_bundle_blocks_upload(self):
        (self.app / 'FirebaseCore_Privacy.bundle/Info.plist').unlink()
        with self.assertRaisesRegex(ValueError, 'missing or invalid FirebaseCore_Privacy'):
            verify(self.project, archive_only=True)


if __name__ == "__main__":
    unittest.main()
