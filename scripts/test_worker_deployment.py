import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('worker_deployment', Path(__file__).with_name('read_worker_deployment.py'))
worker_deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker_deployment)


class WorkerDeploymentTests(unittest.TestCase):
    def receipt(self, **changes):
        return {'type': 'deploy', 'version': 1, 'worker_name': 'watchloom-community',
                'version_id': '11111111-2222-4333-8444-555555555555',
                'targets': ['https://watchloom-community.test-account.workers.dev', 'schedule: * * * * *'],
                **changes}

    def test_confirmed_worker_receipt_ignores_session_urls_and_keeps_one_root(self):
        session = {'type': 'wrangler-session', 'url': 'https://attacker.test/'}
        text = json.dumps(session) + '\n' + json.dumps(self.receipt()) + '\n'
        self.assertEqual(worker_deployment.deployment_endpoint(text),
                         'https://watchloom-community.test-account.workers.dev/')

    def test_failure_stale_receipts_and_wrong_workers_cannot_supply_endpoint(self):
        for rows in [[], [{'type': 'error', 'url': 'https://watchloom-community.old.workers.dev'}],
                     [self.receipt(version_id=None)], [self.receipt(worker_name='puzzle-music-sort')],
                     [self.receipt(version=2)], [self.receipt(), self.receipt()]]:
            with self.assertRaises(ValueError):
                worker_deployment.deployment_endpoint('\n'.join(json.dumps(row) for row in rows))

    def test_unexpected_or_ambiguous_destinations_are_rejected_before_secret_binding(self):
        for targets in [[], ['http://watchloom-community.x.workers.dev'], ['https://evil.test'],
                        ['https://user:secret@watchloom-community.x.workers.dev'],
                        ['https://watchloom-community.x.workers.dev/path'],
                        ['https://watchloom-community.x.workers.dev/?secret=x'],
                        ['https://watchloom-community.x.workers.dev.evil.test'],
                        ['https://watchloom-community.a.workers.dev', 'https://watchloom-community.b.workers.dev'],
                        [None]]:
            with self.assertRaises(ValueError):
                worker_deployment.deployment_endpoint(json.dumps(self.receipt(targets=targets)))

    def test_missing_or_malformed_machine_output_is_not_console_scraped(self):
        for text in ['Deployed https://watchloom-community.x.workers.dev', '{invalid', '[]', '{}']:
            with self.assertRaises(ValueError):
                worker_deployment.deployment_endpoint(text)
