#!/usr/bin/env python3
"""Verify the tested rule revision was deployed and anonymous reads are denied."""
from pathlib import Path
import hashlib
import json
import plistlib
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]


def check():
    config = plistlib.loads((ROOT / 'ios/Runner/GoogleService-Info.plist').read_bytes())
    proof = ROOT / 'build/release-audit/firestore-deployment.json'
    if not proof.exists():
        raise ValueError('Firestore rules are not verified/deployed. Run bash scripts/deploy_firebase.sh --deploy in a normal Terminal.')
    receipt = json.loads(proof.read_text())
    digest = hashlib.sha256((ROOT / 'firebase/firestore.rules').read_bytes()).hexdigest()
    if receipt.get('projectId') != config['PROJECT_ID'] or receipt.get('rulesSha256') != digest or receipt.get('emulatorTestsPassed') is not True:
        raise ValueError('Rules changed since the tested deployment. Run the Firebase deployment check again.')
    for collection in ['users', 'deletionMarkers']:
        query = urlencode({'key': config['API_KEY'], 'pageSize': 1})
        url = f"https://firestore.googleapis.com/v1/projects/{config['PROJECT_ID']}/databases/(default)/documents/{collection}?{query}"
        try:
            with urlopen(url, timeout=15):
                pass
            raise ValueError('Anonymous access is unexpectedly allowed.')
        except HTTPError as error:
            body = json.loads(error.read())
            message = body.get('error', {}).get('message', '').lower()
            if error.code != 403 or 'insufficient permissions' not in message:
                raise ValueError('Firestore did not return the expected security-rules denial. Check API key restrictions and database setup.') from error
        except (URLError, TimeoutError) as error:
            raise ValueError('Could not reach Firestore to verify deployment.') from error
    print('Tested Firestore rule revision deployed; anonymous account/marker reads denied. Device tests are still required.')


if __name__ == '__main__':
    try:
        check()
    except (ValueError, FileNotFoundError) as error:
        sys.exit(f'Release blocked: {error}')
