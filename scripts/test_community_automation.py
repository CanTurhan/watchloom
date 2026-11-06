import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('community_key', Path(__file__).with_name('set_community_api_key.py'))
key_setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(key_setup)


class PrivateModerationKeyTests(unittest.TestCase):
    def test_private_atomic_save_preserves_existing_server_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'private' / 'worker-secrets.json'
            key_setup.save_key('sk-' + 'a' * 40, destination)
            data = json.loads(destination.read_text())
            data['FIREBASE_SERVICE_ACCOUNT'] = 'test-only-existing-key'
            token = data['SETUP_TOKEN']
            destination.write_text(json.dumps(data))
            key_setup.save_key('sk-' + 'b' * 40, destination)
            saved = json.loads(destination.read_text())
            self.assertEqual(saved['FIREBASE_SERVICE_ACCOUNT'], 'test-only-existing-key')
            self.assertEqual(saved['SETUP_TOKEN'], token)
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(destination.parent.stat().st_mode), 0o700)

    def test_repository_path_and_invalid_keys_are_refused(self):
        with self.assertRaises(ValueError):
            key_setup.save_key('not-a-secret-key')
        with self.assertRaises(ValueError):
            key_setup.save_key('sk-' + 'x' * 40, Path(__file__).with_name('worker-secrets.json'))

    def test_symlink_cannot_redirect_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'target'
            target.write_text('unchanged')
            alias = Path(folder) / 'worker-secrets.json'
            alias.symlink_to(target)
            with self.assertRaises(ValueError):
                key_setup.save_key('sk-' + 'x' * 40, alias)
            self.assertEqual(target.read_text(), 'unchanged')
