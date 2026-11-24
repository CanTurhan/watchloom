'use strict';
const crypto = require('node:crypto');
const {document, update, privateOptions} = require('./community_moderation.cjs');
const {endpoint} = require('./community_worker_client.cjs');
const PROJECT = 'watchloom-canturhan', POLICY = '2026-11-06-auto-v1', RELEASE = 'automatic-community-v1';
const base = `/projects/${PROJECT}/databases/(default)/documents`;

function queueProof(data, {requestId, url, requestedAt, now = Date.now()}) {
  const checked = Date.parse(data?.verifiedAt);
  return data?.project === PROJECT && data.policyVersion === POLICY && data.release === RELEASE
    && data.queueProtocol === 1 && data.ready === true && data.requestId === requestId
    && data.endpoint === url && Number.isFinite(checked) && checked >= requestedAt - 30000
    && checked <= now + 30000 && now - checked <= 300000;
}

async function verifyQueueSetup(db, url, dependencies = {}) {
  url = endpoint(url);
  const now = dependencies.now || Date.now;
  const wait = dependencies.wait || (ms => new Promise(resolve => setTimeout(resolve, ms)));
  const requestId = crypto.randomBytes(16).toString('hex'), requestedAt = now();
  // Admin authenticated request only. Mobile security rules deny both paths.
  await db.post(`${base}:commit`, {writes: [update('communityAutomation/verificationRequest',
    {requestId, endpoint: url, state: 'pending', policyVersion: POLICY, release: RELEASE},
    {timestamps: ['requestedAt']})]}, privateOptions());
  const deadline = requestedAt + 150000;
  while (now() < deadline) {
    let proof;
    try { proof = document((await db.get(`${base}/communityAutomation/queueVerification`, privateOptions())).body)?.data; }
    catch (error) { if (error.status !== 404) throw error; }
    if (proof?.requestId === requestId) {
      if (!queueProof(proof, {requestId, url, requestedAt, now: now()})) {
        throw new Error('Scheduled queue verification failed; no readiness verified.');
      }
      return {project: PROJECT, policyVersion: POLICY, release: RELEASE, ready: true, transport: 'firestore-queue'};
    }
    await wait(3000);
  }
  throw new Error('Scheduled queue verification timed out; no readiness verified.');
}
module.exports = {queueProof, verifyQueueSetup};
