import {PROJECT, POLICY, RELEASE, endpointValid, ready} from './policy.mjs';
import {Store} from './google.mjs';
import {verifySetup} from './setup.mjs';
import {readSetupFailure, setupFailure} from './diagnostics.mjs';

// These documents are admin/server-only under Firestore's deny-by-default rules.
// The mobile app cannot request provider checks or write readiness proofs.
const requestPath = 'communityAutomation/verificationRequest';
const resultPath = 'communityAutomation/queueVerification';
function validRequest(data, now) {
  return data?.policyVersion === POLICY && data.release === RELEASE
    && /^[a-f0-9]{32}$/.test(data.requestId || '') && endpointValid(data.endpoint)
    && data.requestedAt instanceof Date && data.requestedAt <= new Date(now.getTime() + 30000)
    && now.getTime() - data.requestedAt.getTime() <= 300000
    && (data.state === 'pending' || (data.state === 'processing'
      && data.leaseUntil instanceof Date && data.leaseUntil <= now));
}

export async function verifyScheduledRequest(env, dependencies = {}) {
  const store = dependencies.store || new Store(env);
  const verify = dependencies.verify || verifySetup;
  const now = dependencies.now || new Date();
  // One cheap read on ordinary ticks; only an actual operator request needs
  // transactions/provider checks. Re-read under a transaction before claiming.
  if (!validRequest((await store.get(requestPath))?.data, now)) return false;
  const lease = crypto.randomUUID();
  const claim = await store.transaction(async tx => {
    const [request, config] = await Promise.all([
      store.get(requestPath, tx), store.get('communityConfig/current', tx)]);
    if (!validRequest(request?.data, now) || !ready(config?.data)
      || new URL(request.data.endpoint).href !== new URL(config.data.moderationEndpoint).href) return null;
    await store.commit([store.set(requestPath, {state: 'processing', lease,
      leaseUntil: new Date(now.getTime() + 90000)})], tx);
    return request.data;
  });
  if (!claim) return false;
  let check;
  try { check = await verify(env, claim.endpoint); }
  catch (error) { check = setupFailure('server_credentials', error); }
  const success = check?.ready === true && check.project === PROJECT
    && check.policyVersion === POLICY && check.release === RELEASE;
  const failure = success ? null : readSetupFailure(check);
  await store.transaction(async tx => {
    const current = await store.get(requestPath, tx);
    if (current?.data.requestId !== claim.requestId || current.data.lease !== lease
      || current.data.state !== 'processing') return;
    await store.commit([
      store.set(requestPath, {state: success ? 'complete' : 'failed', finishedAt: new Date()}),
      store.set(resultPath, {project: PROJECT, policyVersion: POLICY, release: RELEASE,
        queueProtocol: 1, requestId: claim.requestId, endpoint: claim.endpoint,
        ready: success, verifiedAt: new Date(),
        ...(failure ? {stage: failure.stage, code: failure.code,
          ...(failure.upstreamStatus ? {upstreamStatus: failure.upstreamStatus} : {})} : {})}, false),
    ], tx);
  });
  return true;
}
