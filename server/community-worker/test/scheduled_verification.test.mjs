import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyScheduledRequest} from '../src/scheduled_verification.mjs';
import {PROJECT, POLICY, RELEASE} from '../src/policy.mjs';
const requestPath = 'communityAutomation/verificationRequest';
const resultPath = 'communityAutomation/queueVerification';
const endpoint = 'https://watchloom-community.watchloom-canturhan.workers.dev/';
const now = new Date('2026-11-18T12:00:00Z');
function fixture(patch = {}) {
  const docs = new Map([
    ['communityConfig/current', {enabled: true, moderationReady: true, rulesVersion: 2,
      moderationMode: 'automatic', acceptedPolicyVersion: POLICY, moderationEndpoint: endpoint}],
    [requestPath, {requestId: 'a'.repeat(32), endpoint, state: 'pending', requestedAt: now,
      policyVersion: POLICY, release: RELEASE, ...patch}],
  ]);
  const writes = [];
  const store = {
    async get(path) {return docs.has(path) ? {data: structuredClone(docs.get(path))} : null;},
    set(path, data, merge = true) {return {path, data, merge};},
    async transaction(action) {return action('synthetic-transaction');},
    async commit(batch) {for (const write of batch) {writes.push(write.path);
      docs.set(write.path, {...(write.merge ? docs.get(write.path) : {}), ...structuredClone(write.data)});}},
  };
  return {docs, writes, store};
}
const successful = () => ({ready: true, project: PROJECT, policyVersion: POLICY, release: RELEASE});
test('a fresh admin request runs real setup contract once and changes only administrative proof documents', async () => {
  const f = fixture(); let calls = 0;
  const verify = async (_env, url) => {assert.equal(url, endpoint); calls++; return successful();};
  assert.equal(await verifyScheduledRequest({}, {...f, now, verify}), true);
  assert.equal(f.docs.get(resultPath).ready, true);
  assert.equal(f.docs.get(resultPath).requestId, 'a'.repeat(32));
  assert.equal(f.docs.get(resultPath).queueProtocol, 1);
  assert.equal(f.docs.get(requestPath).state, 'complete');
  assert.ok(f.writes.every(path => [requestPath, resultPath].includes(path)));
  assert.equal(await verifyScheduledRequest({}, {...f, now, verify}), false);
  assert.equal(calls, 1);
});
test('missing, expired, unsafe, foreign, or already leased requests perform no provider work', async () => {
  for (const patch of [{requestedAt: new Date(now.getTime() - 300001)},
    {requestedAt: new Date(now.getTime() + 30001)}, {requestId: 'private-invalid'},
    {endpoint: 'https://foreign.example/'}, {policyVersion: 'old'}, {release: 'foreign'},
    {state: 'complete'}, {state: 'processing', leaseUntil: new Date(now.getTime() + 1)}]) {
    const f = fixture(patch); let called = false;
    assert.equal(await verifyScheduledRequest({}, {...f, now, verify: async () => {called = true;}}), false);
    assert.equal(called, false); assert.equal(f.writes.length, 0);
  }
  const f = fixture(); f.docs.delete(requestPath);
  assert.equal(await verifyScheduledRequest({}, {...f, now}), false);
});
test('provider failure never produces ready proof or copies secret error details', async () => {
  for (const response of [{ready: false}, {...successful(), project: 'foreign'}, null]) {
    const f = fixture();
    await verifyScheduledRequest({}, {...f, now, verify: async () => response});
    assert.equal(f.docs.get(resultPath).ready, false);
    assert.equal(f.docs.get(requestPath).state, 'failed');
  }
  const f = fixture();
  await verifyScheduledRequest({}, {...f, now, verify: async () => {throw new Error('private-key-or-body');}});
  assert.equal(f.docs.get(resultPath).ready, false);
  assert.ok(!JSON.stringify([...f.docs]).includes('private-key-or-body'));
});
test('a replaced request cannot receive the previous request proof; expired processing leases can recover', async () => {
  const f = fixture();
  await verifyScheduledRequest({}, {...f, now, verify: async () => {
    f.docs.get(requestPath).requestId = 'b'.repeat(32); return successful();
  }});
  assert.equal(f.docs.has(resultPath), false);
  const retry = fixture({state: 'processing', leaseUntil: now});
  assert.equal(await verifyScheduledRequest({}, {...retry, now, verify: async () => successful()}), true);
});
