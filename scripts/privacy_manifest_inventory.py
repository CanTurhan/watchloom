#!/usr/bin/env python3
"""Inventory actual app/SDK declarations; this is not an App Privacy answer sheet."""

import argparse
import json
import plistlib
from pathlib import Path


def inventory(root):
    records = []
    for path in sorted(root.rglob('PrivacyInfo.xcprivacy')):
        with path.open('rb') as source:
            value = plistlib.load(source)
        records.append({
            'path': str(path.relative_to(root)),
            'tracking': value.get('NSPrivacyTracking', False),
            'trackingDomains': value.get('NSPrivacyTrackingDomains', []),
            'collectedData': value.get('NSPrivacyCollectedDataTypes', []),
            'requiredReasonAPIs': value.get('NSPrivacyAccessedAPITypes', []),
        })
    return records


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='An exported .app or ios/Pods directory')
    parser.add_argument('--output', type=Path, required=True)
    arguments = parser.parse_args()
    if not arguments.root.is_dir():
        parser.error('The selected app or SDK directory does not exist.')
    records = inventory(arguments.root)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps({
        'notice': 'SDK declarations are not proof that every declared data type is collected in this configuration. Review runtime behavior and the provider terms.',
        'manifests': records,
    }, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(records)} privacy manifests inventoried: {arguments.output}')
