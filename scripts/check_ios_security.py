#!/usr/bin/env python3
"""Prevent an iOS release with the pre-patch Firebase trust store."""
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = '12.19.3'
# Firebase 12.19.3 patches Core and Firestore. Its official umbrella podspec
# deliberately keeps Auth on 12.19.0; component versions are not interchangeable.
REQUIRED_PODS = {
    'FirebaseCore': REQUIRED,
    'FirebaseAuth': '12.19.0',
    'FirebaseFirestore': REQUIRED,
    'FirebaseFirestoreInternal': REQUIRED,
}


def validate_bundles(read_info, label):
    """Check actual compiled resources, including a previously exported IPA."""
    for name, expected in REQUIRED_PODS.items():
        relative = f'{name}_Privacy.bundle/Info.plist'
        try:
            info = plistlib.loads(read_info(relative))
        except (OSError, KeyError, ValueError, plistlib.InvalidFileException) as error:
            raise ValueError(f'{label}: missing or invalid {relative}. Rebuild with the current Firebase SDK.') from error
        version = info.get('CFBundleShortVersionString')
        if version != expected:
            raise ValueError(f'{label}: {name} must be {expected}; found {version!r}. Rebuild with the current Firebase SDK.')


def verify_app(app):
    validate_bundles(lambda relative: (app / relative).read_bytes(), 'Archived app')


def check(project=ROOT):
    lock = (project / 'ios/Podfile.lock').read_text()
    for name, expected in REQUIRED_PODS.items():
        match = re.search(r'^  - ' + re.escape(name) + r' \(([^)]+)\)', lock, re.M)
        if match is None or match[1] != expected:
            raise ValueError(f'{name} must resolve to {expected} for Firebase security patch {REQUIRED}. Run bash scripts/update_ios_dependencies.sh before building.')
    manifest = project / 'ios/Pods/Manifest.lock'
    if not manifest.exists() or manifest.read_text() != lock:
        raise ValueError('Installed Pods do not match the verified lockfile. Install the current dependencies.')
    print(f'Firebase native security patch {REQUIRED} verified in lockfile and installed Pods.')


if __name__ == '__main__':
    try:
        check()
    except (ValueError, FileNotFoundError) as error:
        sys.exit(f'Release blocked: {error}')
