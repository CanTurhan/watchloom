import worker from './src/index.mjs';
import {field} from './src/google.mjs';
const json = (data, status = 200) => new Response(JSON.stringify(data), {status, headers: {'Content-Type': 'application/json'}});
const check = (condition, label) => {if (!condition) throw new Error('Runtime assertion failed: ' + label);};
const secretDetail = 'synthetic-provider-detail-must-not-escape';

async function environment(valid) {
  const env = {FIREBASE_PROJECT_ID: 'watchloom-canturhan', OPENAI_MODEL: 'omni-moderation-latest',
    OPENAI_API_KEY: 'synthetic-runtime-key', SETUP_TOKEN: 'd'.repeat(64), FIREBASE_SERVICE_ACCOUNT: '{}'};
  if (!valid) return env;
  const pair = await crypto.subtle.generateKey({name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'}, true, ['sign', 'verify']);
  const encoded = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))));
  env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify({project_id: 'watchloom-canturhan',
    client_email: 'watchloom-community@watchloom-canturhan.iam.gserviceaccount.com',
    private_key: ['-----BEGIN PRIVATE KEY-----', encoded, '-----END PRIVATE KEY-----'].join('\n'),
    token_uri: 'https://oauth2.googleapis.com/token'});
  return env;
}
async function scenario(failure, expectedCode, context) {
  const env = await environment(failure !== 'server_credentials' && failure !== 'unauthorized');
  let proofWritten = false, requests = 0, queries = 0;
  globalThis.fetch = async (target, options) => {
    // Exercise workerd's actual Request parser before synthetic network replies.
    // Node accepts options that Cloudflare's Request implementation rejects.
    const outgoing = new Request(target, options);
    check(outgoing.redirect === 'manual', 'outbound redirects stay manual');
    const url = new URL(outgoing.url); requests++;
    if (url.hostname === 'oauth2.googleapis.com') {
      if (failure === 'oauth_redirect') return new Response('{}', {status: 302, headers: {Location: 'https://foreign.test/'}});
      if (failure === 'google_oauth') return json({error: 'invalid_grant', error_description: secretDetail}, 400);
      return json({access_token: 'synthetic-runtime-token', expires_in: 3600});
    }
    if (url.hostname === 'identitytoolkit.googleapis.com') {
      if (failure === 'firebase_auth') return json({error: {status: 'PERMISSION_DENIED', message: secretDetail}}, 403);
      return json({});
    }
    if (url.hostname === 'firestore.googleapis.com') {
      if (url.pathname.endsWith(':runQuery')) {
        queries++;
        if (failure === 'firestore_redirect') return new Response('{}', {status: 307, headers: {Location: 'https://foreign.test/'}});
        if ((failure === 'pending_index' && queries === 1) || (failure === 'ranking_index' && queries === 2)) {
          return json({error: {status: 'FAILED_PRECONDITION', message: 'Create index https://private.test/?key=' + secretDetail}}, 400);
        }
        return json([]);
      }
      if (failure === 'health_write') return json({error: {status: 'PERMISSION_DENIED', message: secretDetail}}, 403);
      proofWritten = true; return json({});
    }
    if (url.hostname === 'api.openai.com') {
      if (failure === 'openai_redirect') return new Response('{}', {status: 308, headers: {Location: 'https://foreign.test/'}});
      if (failure === 'openai_moderation') return json({error: {code: 'invalid_api_key', message: secretDetail}}, 401);
      const categories = {hate: false, harassment: false, sexual: false, violence: false, 'self-harm': false};
      const result = {flagged: false, categories, category_scores: Object.fromEntries(Object.keys(categories).map(k => [k, 0.001]))};
      return json({model: 'synthetic-runtime-model', results: [result, result]});
    }
    throw new Error('Unexpected outbound destination');
  };
  const request = new Request('https://watchloom-community.watchloom-canturhan.workers.dev/v1/verify-setup',
    {method: 'POST', headers: {'Content-Type': 'application/json',
      ...(failure === 'unauthorized' ? {} : {Authorization: 'Bearer ' + env.SETUP_TOKEN})}, body: '{}'});
  const response = await worker.fetch(request, env, context);
  const result = await response.json();
  const output = JSON.stringify(result);
  check(!output.includes(secretDetail) && !output.includes(env.SETUP_TOKEN) && !output.includes(env.OPENAI_API_KEY), 'no private data');
  if (failure === 'unauthorized') {
    check(response.status === 401 && result.error === 'unauthorized' && !result.stage, 'owner-only details');
    check(requests === 0 && !proofWritten, 'no unauthenticated work');
  } else if (failure) {
    const expectedStage = {oauth_redirect: 'google_oauth', firestore_redirect: 'pending_index', openai_redirect: 'openai_moderation'}[failure] || failure;
    check(response.status === 503 && result.ready === false && result.stage === expectedStage && result.code === expectedCode, 'precise bounded failure');
    check(!proofWritten, 'no failure proof');
  } else check(response.status === 200 && result.ready === true && proofWritten, 'complete success proof');
  console.log(JSON.stringify({runtimeCase: failure || 'successful_setup', status: 'passed'}));
}
async function scheduledScenario() {
  const env = await environment(true);
  const prefix = 'projects/watchloom-canturhan/databases/(default)/documents/';
  const endpoint = 'https://watchloom-community.watchloom-canturhan.workers.dev/';
  const docs = new Map([
    ['communityAutomation/verificationRequest', {requestId: 'a'.repeat(32), state: 'pending', endpoint,
      requestedAt: new Date(), policyVersion: '2026-11-06-auto-v1', release: 'automatic-community-v1'}],
    ['communityConfig/current', {enabled: true, moderationReady: true, rulesVersion: 2,
      moderationMode: 'automatic', acceptedPolicyVersion: '2026-11-06-auto-v1', moderationEndpoint: endpoint}],
  ].map(([path, data]) => [prefix + path, {name: prefix + path,
    fields: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, field(value)]))}]));
  let classifications = 0;
  globalThis.fetch = async (target, options) => {
    const outgoing = new Request(target, options), url = new URL(outgoing.url);
    check(outgoing.redirect === 'manual', 'scheduled redirects are not followed');
    if (url.hostname === 'oauth2.googleapis.com') return json({access_token: 'synthetic-scheduled-token', expires_in: 3600});
    if (url.hostname === 'identitytoolkit.googleapis.com') return json({});
    if (url.hostname === 'api.openai.com') {
      classifications++;
      const categories = {hate: false, harassment: false, sexual: false, violence: false, 'self-harm': false};
      const result = {flagged: false, categories, category_scores: Object.fromEntries(Object.keys(categories).map(k => [k, 0.001]))};
      return json({model: 'synthetic-scheduled-model', results: [result, result]});
    }
    check(url.hostname === 'firestore.googleapis.com', 'scheduled checks use only approved provider hosts');
    if (outgoing.method === 'GET') {
      const name = decodeURIComponent(url.pathname.slice('/v1/'.length));
      return docs.has(name) ? json(docs.get(name)) : json({error: {status: 'NOT_FOUND'}}, 404);
    }
    if (url.pathname.endsWith(':beginTransaction')) return json({transaction: 'scheduled-transaction'});
    if (url.pathname.endsWith(':rollback')) return json({});
    if (url.pathname.endsWith(':runQuery')) return json([]);
    if (url.pathname.endsWith(':commit')) {
      const body = await outgoing.json();
      for (const write of body.writes) {
        check(write.update.name.startsWith(prefix + 'communityAutomation/'), 'synthetic check does not mutate user data');
        const previous = write.updateMask ? docs.get(write.update.name)?.fields : {};
        docs.set(write.update.name, {name: write.update.name, fields: {...previous, ...write.update.fields}});
      }
      return json({});
    }
    throw new Error('Unexpected scheduled provider operation');
  };
  let completion;
  await worker.scheduled({}, env, {waitUntil(value) {completion = value;}});
  await completion;
  const proof = docs.get(prefix + 'communityAutomation/queueVerification')?.fields;
  check(proof?.ready?.booleanValue === true && proof.queueProtocol.integerValue === '1'
    && proof.requestId.stringValue === 'a'.repeat(32), 'live-runtime scheduled nonce-bound proof');
  check(docs.has(prefix + 'communityAutomation/health') && classifications === 1, 'all scheduled provider checks ran');
  console.log(JSON.stringify({runtimeCase: 'scheduled_operator_verification', status: 'passed'}));
}
export default {
  async test(controller, bindings, context) {
    const original = globalThis.fetch;
    try {
      for (const [failure, code] of [[null, null], ['server_credentials', 'CHECK_FAILED'],
        ['google_oauth', 'invalid_grant'], ['firebase_auth', 'PERMISSION_DENIED'],
        ['pending_index', 'INDEX_NOT_READY'], ['ranking_index', 'INDEX_NOT_READY'],
        ['openai_moderation', 'invalid_api_key'], ['health_write', 'PERMISSION_DENIED'], ['unauthorized', null],
        ['oauth_redirect', 'UPSTREAM_HTTP_ERROR'], ['firestore_redirect', 'UPSTREAM_HTTP_ERROR'], ['openai_redirect', 'UPSTREAM_HTTP_ERROR']]) {
        await scenario(failure, code, context);
      }
      await scheduledScenario();
    } finally {globalThis.fetch = original;}
  }
};
