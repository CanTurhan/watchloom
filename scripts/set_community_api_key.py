#!/usr/bin/env python3
"""Collect the moderation key without echoing it or placing it in the repository."""
import getpass
import json
import os
from pathlib import Path
import re
import secrets
import stat
import tempfile


def save_key(key, destination=None):
    if not re.fullmatch(r'sk-[A-Za-z0-9_-]{20,500}', key):
        raise ValueError('Use an OpenAI API secret key, not a ChatGPT password or session token.')
    destination = destination or Path.home() / '.config/watchloom/community/worker-secrets.json'
    destination = Path(destination)
    repository = Path(__file__).resolve().parents[1]
    if destination.is_symlink() or destination.parent.is_symlink():
        raise ValueError('A private regular file and directory are required.')
    if destination.resolve().is_relative_to(repository):
        raise ValueError('The secret file must be outside the repository.')
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination.parent.chmod(0o700)
    if destination.exists():
        if not stat.S_ISREG(destination.stat().st_mode):
            raise ValueError('Expected a regular private secret file.')
        destination.chmod(0o600)
        data = json.loads(destination.read_text())
    else:
        data = {}
    data['OPENAI_API_KEY'] = key
    data.setdefault('SETUP_TOKEN', secrets.token_hex(32))
    handle, temporary = tempfile.mkstemp(prefix='.worker-secrets-', dir=destination.parent)
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, 'w') as stream:
            json.dump(data, stream)
            stream.write('\n')
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return destination


if __name__ == '__main__':
    try:
        saved = save_key(getpass.getpass('OpenAI Moderation API key (hidden): ').strip())
        print(f'Key saved privately outside the repository: {saved}')
        print('No key was printed, sent to chat, or copied into the app. Server setup is next.')
    except (ValueError, OSError, EOFError, KeyboardInterrupt):
        raise SystemExit('Key setup stopped. Use a valid API key in a normal Terminal; no successful setup was verified.')
