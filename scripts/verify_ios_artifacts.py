#!/usr/bin/env python3
"""Check an archive, or an archive and IPA, against the current release."""

import argparse
import plistlib
import re
import sys
import zipfile
from pathlib import Path
from check_ios_security import validate_bundles, verify_app


def validate_info(info, label, version, build, minimum_os=None):
    expected = {
        "CFBundleIdentifier": "com.canturhan.watchloom",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
    }
    if minimum_os is not None:
        expected["MinimumOSVersion"] = minimum_os
    for key, value in expected.items():
        if info.get(key) != value:
            recovery = (
                "Re-export the current archive before uploading this IPA."
                if label == "IPA"
                else "Build the current source before uploading."
            )
            raise ValueError(
                f"{label}: {key} must be {value!r}; found {info.get(key)!r}. "
                + recovery
            )


def verify(project, *, archive_only=False):
    match = re.search(
        r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
        (project / "pubspec.yaml").read_text(),
        re.MULTILINE,
    )
    if match is None:
        raise ValueError("Cannot read the expected version and build from pubspec.yaml.")
    version, build = match.groups()
    minimum_match = re.search(
        r"^platform\s+:ios,\s*['\"]([\d.]+)['\"]",
        (project / "ios/Podfile").read_text(),
        re.MULTILINE,
    )
    if minimum_match is None:
        raise ValueError("Cannot read the minimum iOS version from ios/Podfile.")
    minimum_os = minimum_match.group(1)
    archive = project / "build/ios/archive/Runner.xcarchive"
    archive_info = plistlib.loads((archive / "Info.plist").read_bytes())
    validate_info(archive_info.get("ApplicationProperties", {}), "Archive", version, build)

    apps = list((archive / "Products/Applications").glob("*.app"))
    if len(apps) != 1:
        raise ValueError("Expected exactly one app in the archive.")
    validate_info(
        plistlib.loads((apps[0] / "Info.plist").read_bytes()),
        "Archived app", version, build, minimum_os,
    )
    if any(apps[0].rglob("*.storekit")):
        raise ValueError("The archive contains a local StoreKit test configuration.")
    verify_app(apps[0])

    # xcodebuild -exportArchive uploads this archive directly and re-signs it;
    # it never consumes build/ios/ipa. An older or missing IPA must not block a
    # correctly verified archive after a failed local export.
    if archive_only:
        print(f"Verified Watchloom {version} ({build}), iOS {minimum_os}: archive metadata matches.")
        print(f"Archive: {archive}")
        return

    ipas = list((project / "build/ios/ipa").glob("*.ipa"))
    if len(ipas) != 1:
        raise ValueError("Expected exactly one IPA in build/ios/ipa; check the export output.")
    with zipfile.ZipFile(ipas[0]) as package:
        main_info = [
            name for name in package.namelist()
            if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)
        ]
        if len(main_info) != 1:
            raise ValueError("Expected exactly one main app Info.plist in the IPA.")
        validate_info(
            plistlib.loads(package.read(main_info[0])), "IPA", version, build, minimum_os,
        )
        if any(name.endswith(".storekit") for name in package.namelist()):
            raise ValueError("The IPA contains a local StoreKit test configuration.")
        app_prefix = main_info[0].removesuffix('Info.plist')
        validate_bundles(lambda relative: package.read(app_prefix + relative), 'IPA')
    print(f"Verified Watchloom {version} ({build}), iOS {minimum_os}: archive and IPA metadata match.")
    print(f"IPA: {ipas[0]}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--archive-only", action="store_true",
        help="Verify the archive for direct Xcode upload without checking a local IPA.",
    )
    args = parser.parse_args()
    try:
        verify(Path(__file__).resolve().parents[1], archive_only=args.archive_only)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"Release verification failed: {error}", file=sys.stderr)
        sys.exit(1)
