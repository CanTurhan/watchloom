'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {migratedFields, endpoint, verifiedHealth, automaticConfiguration} = require('./configure_community_automation.cjs');
test('ranking migration preserves existing votes and refuses inconsistent partial counters', () => {
  assert.deepEqual(migratedFields({body: 'legacy'}), {scoreSchema: 1, upVotes: 0, downVotes: 0, score: 0});
  assert.deepEqual(migratedFields({scoreSchema: 1, upVotes: 9, downVotes: 2, score: 7}), {});
  assert.deepEqual(migratedFields({upVotes: 9, downVotes: 2, score: 7}), {scoreSchema: 1});
  for (const input of [{upVotes: 9}, {scoreSchema: 1}, {scoreSchema: 2, upVotes: 0, downVotes: 0, score: 0}, {upVotes: 9, downVotes: 2, score: 0},
    {upVotes: -1, downVotes: 0, score: -1}, {upVotes: 1.5, downVotes: 0, score: 1.5}]) assert.throws(() => migratedFields(input));
});
test('automation setup accepts only a safe HTTPS workers.dev root, without secret-carrying URL components', () => {
  assert.equal(endpoint('https://watchloom-community.my-account.workers.dev'), 'https://watchloom-community.my-account.workers.dev/');
  for (const input of ['https://evil.test', 'http://watchloom-community.x.workers.dev/',
    'https://user:secret@watchloom-community.x.workers.dev/', 'https://watchloom-community.x.workers.dev/key',
    'https://watchloom-community.x.workers.dev/?key=secret', 'https://watchloom-community.x.workers.dev/#secret',
    'https://watchloom-community.x.workers.dev:444/']) assert.throws(() => endpoint(input));
});
test('activation proof rejects missing, malformed, stale, future and mismatched Worker health data', () => {
  const url = 'https://watchloom-community.example.workers.dev/', now = Date.now();
  const healthy = {project: 'watchloom-canturhan', policyVersion: '2026-11-06-auto-v1',
    release: 'automatic-community-v1', endpoint: url, verifiedAt: new Date(now).toISOString()};
  assert.equal(verifiedHealth(healthy, url, now), true);
  for (const value of [null, {}, {...healthy, verifiedAt: null}, {...healthy, verifiedAt: 'invalid'},
    {...healthy, verifiedAt: new Date(now - 300001).toISOString()}, {...healthy, verifiedAt: new Date(now + 30001).toISOString()},
    {...healthy, project: 'puzzle-music-sort-canturhan'}, {...healthy, endpoint: 'https://other.example.workers.dev/'},
    {...healthy, release: 'other'}, {...healthy, policyVersion: 'old'}]) assert.equal(verifiedHealth(value, url, now), false);
});
test('release verification fails closed on paused, malformed or incomplete automatic configuration', () => {
  const url = 'https://watchloom-community.example.workers.dev/';
  const ready = {enabled: true, moderationReady: true, rulesVersion: 2, moderationMode: 'automatic',
    acceptedPolicyVersion: '2026-11-06-auto-v1', moderationEndpoint: url};
  assert.equal(automaticConfiguration(ready, url), true);
  for (const config of [null, {}, {...ready, enabled: false}, {...ready, enabled: 'true'},
    {...ready, moderationReady: 'true'}, {...ready, rulesVersion: 1}, {...ready, moderationMode: 'owner-cli'},
    {...ready, acceptedPolicyVersion: 'old'}, {...ready, moderationEndpoint: 'https://evil.test/'}]) {
    assert.equal(automaticConfiguration(config), false);
  }
  assert.equal(automaticConfiguration(ready, 'https://other.example.workers.dev/'), false);
});
