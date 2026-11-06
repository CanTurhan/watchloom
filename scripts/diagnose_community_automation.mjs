#!/usr/bin/env node
// Runs in the owner's Terminal. Reads existing private configuration, prints
// only stage/status/whitelisted codes, and sends only synthetic text to OpenAI.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {PROJECT, POLICY, RELEASE} from '../server/community-worker/src/policy.mjs';
import {account, googleToken, lookupUser, Store, limitedText} from '../server/community-worker/src/google.mjs';
import {ModerationService} from '../server/community-worker/src/moderation.mjs';
const require = createRequire(import.meta.url);
const {endpoint} = require('./configure_community_automation.cjs');
const {safeProviderCode, safeNetworkCode} = require('./community_diagnostics.cjs');
const emit = value => process.stdout.write(JSON.stringify(value) + '\n');
let currentStage = 'private_configuration';
let lastFailure;
const nativeFetch = globalThis.fetch;

async function step(stage, action) {
  currentStage = stage; lastFailure = null;
  emit({stage, status: 'checking'});
  try { await action(); emit({stage, status: 'passed'}); return true; }
  catch {
    emit({stage, status: 'failed', ...(lastFailure || {code: 'INVALID_OR_UNEXPECTED_RESPONSE'})});
    return false;
  }
}

try {
  const root = endpoint(process.argv[2]);
  const privateFile = path.join(os.homedir(), '.config/watchloom/community/worker-secrets.json');
  const secrets = JSON.parse(fs.readFileSync(privateFile, 'utf8'));
  if (!/^[a-f0-9]{64}$/.test(secrets.SETUP_TOKEN || '') || typeof secrets.OPENAI_API_KEY !== 'string') throw new Error();
  const env = {...secrets, FIREBASE_PROJECT_ID: PROJECT, OPENAI_MODEL: 'omni-moderation-latest', DAILY_MODERATION_LIMIT: '500'};
  const workerHost = new URL(root).hostname;
  const hosts = new Set([workerHost, 'oauth2.googleapis.com', 'identitytoolkit.googleapis.com', 'firestore.googleapis.com', 'api.openai.com']);
  globalThis.fetch = async (url, options) => {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' || !hosts.has(parsed.hostname)) throw new Error();
    let response;
    try { response = await nativeFetch(url, options); }
    catch (error) { lastFailure = {code: safeNetworkCode(error)}; throw error; }
    if (!response.ok) {
      let data;
      try { data = JSON.parse(await limitedText(response.clone(), 64 * 1024)); } catch {}
      lastFailure = {httpStatus: response.status, code: safeProviderCode(data)};
    }
    return response;
  };
  const remoteReady = await step('deployed_worker', async () => {
    const response = await fetch(new URL('/v1/verify-setup', root), {method: 'POST', redirect: 'error',
      headers: {'Content-Type': 'application/json', Authorization: `Bearer ${secrets.SETUP_TOKEN}`},
      body: '{}', signal: AbortSignal.timeout(30000)});
    if (!response.ok) throw new Error();
    const data = JSON.parse(await limitedText(response, 64 * 1024));
    if (data.ready !== true || data.project !== PROJECT || data.policyVersion !== POLICY || data.release !== RELEASE) throw new Error();
  });
  if (remoteReady) {
    emit({result: 'worker_verified', next: 'activate_then_release'});
  } else {
    const store = new Store(env), service = new ModerationService(env);
    const checks = [
      ['server_credentials', async () => { account(env); }],
      ['google_oauth', async () => { await googleToken(env); }],
      ['firebase_auth', async () => { await lookupUser(env, 'watchloom_setup_check'); }],
      ['pending_index', async () => { await store.query('communityComments', [['status', 'EQUAL', 'pending'],
        ['policyVersion', 'EQUAL', POLICY], ['moderationNextAt', 'LESS_THAN_OR_EQUAL', new Date()]], 'moderationNextAt'); }],
      ['ranking_index', async () => { await store.api(':runQuery', {structuredQuery: {from: [{collectionId: 'communityComments'}],
        where: {compositeFilter: {op: 'AND', filters: [
          {fieldFilter: {field: {fieldPath: 'contentKey'}, op: 'EQUAL', value: {stringValue: 'tvmaze:show:1'}}},
          {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: {stringValue: 'approved'}}}]}},
        orderBy: [{field: {fieldPath: 'score'}, direction: 'DESCENDING'},
          {field: {fieldPath: 'createdAt'}, direction: 'DESCENDING'}], limit: 1}}); }],
      ['openai_moderation', async () => {
        const verdict = await service.classify({body: 'I enjoyed the story and the soundtrack.', authorName: 'Watchloom setup check'});
        if (verdict.status !== 'approved') throw new Error();
      }],
    ];
    let failed = false;
    for (const [stage, action] of checks) {
      if (!await step(stage, action)) { failed = true; break; }
    }
    emit({result: failed ? 'dependency_failure_identified' : 'local_dependencies_passed_worker_needs_investigation', credentialsPrinted: false});
    process.exitCode = 1;
  }
} catch {
  emit({stage: currentStage, status: 'failed', code: 'PRIVATE_CONFIGURATION_OR_ENDPOINT_INVALID', credentialsPrinted: false});
  process.exitCode = 1;
} finally { globalThis.fetch = nativeFetch; }
