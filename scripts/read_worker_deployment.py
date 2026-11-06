#!/usr/bin/env python3
"""Read the pinned Wrangler deployment receipt without intercepting its TTY."""
import json
from pathlib import Path
import re
import sys


def deployment_endpoint(text):
    if not isinstance(text, str) or len(text) > 1024 * 1024:
        raise ValueError('Invalid deployment receipt')
    records = [json.loads(line) for line in text.splitlines() if line.strip()]
    if not all(isinstance(record, dict) for record in records):
        raise ValueError('Invalid deployment record')
    deployments = [record for record in records if record.get('type') == 'deploy']
    if len(deployments) != 1:
        raise ValueError('Expected one successful deployment')
    deployed = deployments[0]
    if (deployed.get('version') != 1 or deployed.get('worker_name') != 'watchloom-community'
            or not isinstance(deployed.get('version_id'), str) or not deployed['version_id']
            or not isinstance(deployed.get('targets'), list)):
        raise ValueError('Unexpected Worker deployment')
    roots = set()
    for target in deployed['targets']:
        if not isinstance(target, str):
            raise ValueError('Invalid deployment target')
        if re.fullmatch(r'https://watchloom-community\.[a-z0-9-]+\.workers\.dev/?', target):
            roots.add(target.rstrip('/') + '/')
        elif not target.startswith('schedule: '):
            raise ValueError('Unexpected deployment target')
    if len(roots) != 1:
        raise ValueError('Expected one Watchloom workers.dev endpoint')
    return roots.pop()


if __name__ == '__main__':
    try:
        print(deployment_endpoint(Path(sys.argv[1]).read_text()))
    except (IndexError, OSError, ValueError, TypeError):
        raise SystemExit('Could not verify the deployed Watchloom Worker receipt. No secret upload or activation attempted.')
