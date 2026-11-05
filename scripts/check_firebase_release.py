#!/usr/bin/env python3
"""Reject an iOS release that ships the unconfigured account feature."""
from pathlib import Path
import plistlib
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'scripts'))
from configure_firebase_ios import validate  # noqa: E402


def check():
    path = root / 'ios/Runner/GoogleService-Info.plist'
    if not path.exists():
        raise ValueError('Watchloom Firebase project is not configured. Configure the iOS app before archiving/uploading build 6.')
    config = plistlib.loads(path.read_bytes())
    validate(config)
    info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
    schemes = [scheme for item in info.get('CFBundleURLTypes', []) for scheme in item.get('CFBundleURLSchemes', [])]
    if config['REVERSED_CLIENT_ID'] not in schemes or info.get('GIDClientID') != config['CLIENT_ID']:
        raise ValueError('Google Sign-In URL configuration is missing or stale.')
    options = (root / 'lib/firebase_options.dart').read_text()
    if 'get ios => null' in options or config['GOOGLE_APP_ID'] not in options or config['PROJECT_ID'] not in options:
        raise ValueError('Dart Firebase configuration does not match the native iOS app.')
    entitlements = plistlib.loads((root / 'ios/Runner/Runner.entitlements').read_bytes())
    if entitlements.get('com.apple.developer.applesignin') != ['Default']:
        raise ValueError('Sign in with Apple entitlement is missing.')
    project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
    if 'GoogleService-Info.plist in Resources' not in project:
        raise ValueError('Firebase configuration is not included in the iOS bundle.')
    print('Firebase iOS client configuration verified. Provider/backend device tests are still required.')


if __name__ == '__main__':
    try:
        check()
    except (ValueError, FileNotFoundError) as error:
        sys.exit(f'Release blocked: {error}')
