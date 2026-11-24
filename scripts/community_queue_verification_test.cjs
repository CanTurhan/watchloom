'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {queueProof, verifyQueueSetup} = require('./community_queue_verification.cjs');
const url = 'https://watchloom-community.watchloom-canturhan.workers.dev/';
const start = Date.parse('2026-11-18T12:00:00Z');
const identity = {requestId: 'a'.repeat(32), url, requestedAt: start, now: start};
const proof = () => ({project: 'watchloom-canturhan', policyVersion: '2026-11-06-auto-v1',
  release: 'automatic-community-v1', queueProtocol: 1, requestId: identity.requestId,
  endpoint: url, ready: true, verifiedAt: new Date(start).toISOString()});
test('only fresh nonce-bound current-project queue proofs establish readiness', () => {
  assert.equal(queueProof(proof(), identity), true);
  for (const patch of [{ready: false}, {ready: 'true'}, {project: 'foreign'}, {policyVersion: 'old'},
    {release: 'old'}, {queueProtocol: 2}, {requestId: 'b'.repeat(32)}, {endpoint: 'https://foreign.test/'},
    {verifiedAt: new Date(start - 30001).toISOString()}, {verifiedAt: new Date(start + 30001).toISOString()},
    {verifiedAt: 'not-a-date'}]) assert.equal(queueProof({...proof(), ...patch}, identity), false);
});
test('owner setup posts only an admin probe and waits for the matching server result', async () => {
  let clock = start, requestedId, reads = 0;
  const db = {
    async post(path, data, options) {
      assert.ok(path.endsWith('/documents:commit'));
      assert.equal(data.writes.length, 1);
      const write = data.writes[0];
      assert.ok(write.update.name.endsWith('/communityAutomation/verificationRequest'));
      requestedId = write.update.fields.requestId.stringValue;
      assert.match(requestedId, /^[a-f0-9]{32}$/);
      assert.equal(options.skipLog.body, true);
    },
    async get() {reads++; if (reads === 1) throw Object.assign(new Error(), {status: 404});
      return {body: {name: 'projects/watchloom-canturhan/databases/(default)/documents/communityAutomation/queueVerification',
        fields: Object.fromEntries(Object.entries({...proof(), requestId: requestedId}).map(([key, value]) =>
          [key, typeof value === 'boolean' ? {booleanValue: value} : typeof value === 'number' ? {integerValue: String(value)} : {stringValue: value}]))}};
    },
  };
  const result = await verifyQueueSetup(db, url, {now: () => clock, wait: async ms => {clock += ms;}});
  assert.equal(result.ready, true); assert.equal(result.transport, 'firestore-queue'); assert.equal(reads, 2);
});
test('missing server response times out without readiness and unsafe endpoints never write', async () => {
  let clock = start, writes = 0;
  const db = {async post() {writes++;}, async get() {throw Object.assign(new Error(), {status: 404});}};
  await assert.rejects(verifyQueueSetup(db, url, {now: () => clock, wait: async ms => {clock += ms;}}), /timed out/);
  assert.equal(writes, 1);
  await assert.rejects(verifyQueueSetup(db, 'http://foreign.test/'), /HTTPS/);
  assert.equal(writes, 1);
});
