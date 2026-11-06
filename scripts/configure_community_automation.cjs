'use strict';
// Owner CLI only. Secrets stay outside Git; no billing or paid APIs enabled.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {check} = require('./check_firebase_spark.cjs');
const {privateOptions, document, update} = require('./community_moderation.cjs');
const {endpoint, verifyWorkerSetup, workerFailureDetails} = require('./community_worker_client.cjs');
const PROJECT = 'watchloom-canturhan';
const POLICY = '2026-11-06-auto-v1';
const SECRET = path.join(os.homedir(), '.config/watchloom/community/worker-secrets.json');
const ACCOUNT = `watchloom-community@${PROJECT}.iam.gserviceaccount.com`;
const DB = `/projects/${PROJECT}/databases/(default)/documents`;
let phase = 'arguments';

function readSecrets() {
  if (!fs.existsSync(SECRET) || fs.lstatSync(SECRET).isSymbolicLink() || !fs.lstatSync(SECRET).isFile()) {
    throw new Error('Run python3 scripts/set_community_api_key.py first. Never paste credentials into chat.');
  }
  fs.chmodSync(SECRET, 0o600);
  const data = JSON.parse(fs.readFileSync(SECRET, 'utf8'));
  if (!/^sk-[A-Za-z0-9_-]{20,500}$/.test(data.OPENAI_API_KEY || '') || !/^[a-f0-9]{64}$/.test(data.SETUP_TOKEN || '')) {
    throw new Error('The private configuration is incomplete. Run the API key setup again.');
  }
  return data;
}
function saveSecrets(data) {
  const temporary = path.join(path.dirname(SECRET), `.worker-secrets-${crypto.randomBytes(8).toString('hex')}`);
  try {
    fs.writeFileSync(temporary, JSON.stringify(data) + '\n', {flag: 'wx', mode: 0o600});
    fs.renameSync(temporary, SECRET);
  } finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}
function migratedFields(data) {
  if (Object.hasOwn(data, 'scoreSchema') && data.scoreSchema !== 1) throw new Error('Unsupported score schema; migration stopped.');
  const fields = ['upVotes', 'downVotes', 'score'];
  const present = fields.filter(k => Object.hasOwn(data, k));
  if (!present.length) {
    if (Object.hasOwn(data, 'scoreSchema')) throw new Error('A versioned score is missing counters; migration stopped.');
    return {scoreSchema: 1, upVotes: 0, downVotes: 0, score: 0};
  }
  if (present.length !== 3 || !fields.every(k => Number.isSafeInteger(data[k]))
    || data.upVotes < 0 || data.downVotes < 0 || data.upVotes > 1000000000 || data.downVotes > 1000000000
    || data.score !== data.upVotes - data.downVotes) throw new Error('Inconsistent existing scores. Migration stopped without resetting votes.');
  return data.scoreSchema === 1 ? {} : {scoreSchema: 1};
}
function assertReceipt() {
  const root = path.resolve(__dirname, '..');
  const receipt = JSON.parse(fs.readFileSync(path.join(root, 'build/release-audit/firestore-deployment.json')));
  const digest = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'firebase/firestore.rules'))).digest('hex');
  if (receipt.projectId !== PROJECT || receipt.emulatorTestsPassed !== true || receipt.rulesSha256 !== digest) {
    throw new Error('Deploy the current emulator-tested rules first: bash scripts/deploy_firebase.sh --deploy');
  }
}
function verifiedHealth(data, url, now = Date.now()) {
  const checked = Date.parse(data?.verifiedAt);
  return !!data && data.project === PROJECT && data.policyVersion === POLICY
    && data.release === 'automatic-community-v1' && data.endpoint === url
    && Number.isFinite(checked) && checked <= now + 30000 && now - checked <= 300000;
}
function automaticConfiguration(data, expectedEndpoint) {
  if (!data || data.enabled !== true || data.moderationReady !== true || data.rulesVersion !== 2
    || data.moderationMode !== 'automatic' || data.acceptedPolicyVersion !== POLICY) return false;
  try { return expectedEndpoint === undefined ? !!endpoint(data.moderationEndpoint) : endpoint(data.moderationEndpoint) === expectedEndpoint; }
  catch { return false; }
}
async function run(args) {
  const [command, target] = args;
  if (!['prepare', 'migrate', 'activate', 'verify'].includes(command)) throw new Error('Usage: node scripts/configure_community_automation.cjs prepare|migrate|activate HTTPS_WORKER_ROOT|verify');
  phase = 'private moderation configuration';
  const secrets = readSecrets();
  if (command === 'activate' && !args.includes('--accept-automated-moderation-responsibility')) {
    throw new Error('Read firebase/COMMUNITY_AUTOMATION.md and pass --accept-automated-moderation-responsibility.');
  }
  let url = command === 'activate' ? endpoint(target) : null;
  if (command !== 'prepare') { phase = 'current emulator-tested rule receipt'; assertReceipt(); }
  phase = 'Firebase CLI login and Spark billing verification';
  const {root} = await check(PROJECT);
  const {Client} = require(path.join(root, 'lib/apiv2'));
  const iam = new Client({urlPrefix: 'https://iam.googleapis.com', apiVersion: 'v1'});
  const crm = new Client({urlPrefix: 'https://cloudresourcemanager.googleapis.com', apiVersion: 'v1'});
  const db = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1'});
  if (command === 'prepare') {
    phase = 'dedicated Google service identity';
    try { await iam.get(`/projects/-/serviceAccounts/${ACCOUNT}`, privateOptions()); }
    catch (error) {
      if (error.status !== 404) throw error;
      await iam.post(`/projects/${PROJECT}/serviceAccounts`, {accountId: 'watchloom-community',
        serviceAccount: {displayName: 'Watchloom automated community', description: 'Dedicated server moderation; never bundled in the iOS app.'}}, privateOptions());
    }
    phase = 'dedicated service IAM permissions';
    const policy = (await crm.post(`/projects/${PROJECT}:getIamPolicy`, {options: {requestedPolicyVersion: 3}}, privateOptions())).body;
    policy.bindings ||= [];
    let changed = false;
    for (const role of ['roles/datastore.user', 'roles/firebaseauth.viewer']) {
      let binding = policy.bindings.find(b => b.role === role && !b.condition);
      if (!binding) {binding = {role, members: []}; policy.bindings.push(binding);}
      if (!binding.members.includes(`serviceAccount:${ACCOUNT}`)) {binding.members.push(`serviceAccount:${ACCOUNT}`); changed = true;}
    }
    if (changed) await crm.post(`/projects/${PROJECT}:setIamPolicy`, {policy}, privateOptions());
    phase = 'private service credential preparation';
    if (secrets.FIREBASE_SERVICE_ACCOUNT) {
      const previous = JSON.parse(secrets.FIREBASE_SERVICE_ACCOUNT);
      if (previous.project_id !== PROJECT || previous.client_email !== ACCOUNT) throw new Error('Unexpected service account in the private file; nothing overwritten.');
    } else {
      const key = (await iam.post(`/projects/-/serviceAccounts/${ACCOUNT}/keys`,
        {privateKeyType: 'TYPE_GOOGLE_CREDENTIALS_FILE', keyAlgorithm: 'KEY_ALG_RSA_2048'}, privateOptions())).body;
      const data = JSON.parse(Buffer.from(key.privateKeyData, 'base64').toString('utf8'));
      if (data.project_id !== PROJECT || data.client_email !== ACCOUNT) throw new Error('Unexpected credential response.');
      secrets.FIREBASE_SERVICE_ACCOUNT = JSON.stringify(data);
      saveSecrets(secrets);
    }
    console.log('Dedicated moderation identity prepared; no billing linked. Private keys remain outside the app/repository.');
    return;
  }
  if (command === 'migrate') {
    phase = 'legacy ranking and consent migration';
    let token, total = 0;
    do {
      const body = (await db.get(`${DB}/communityComments`, privateOptions({pageSize: 100, ...(token ? {pageToken: token} : {})}))).body;
      const writes = [];
      for (const raw of body.documents || []) {
        const doc = document(raw), patch = migratedFields(doc.data);
        if (doc.data.status === 'pending' && doc.data.policyVersion !== POLICY) {
          Object.assign(patch, {status: 'rejected', moderationReason: 'consentRequired', moderationSource: 'policy-migration'});
        }
        if (Object.keys(patch).length) {
          const write = update(doc.id, patch, {patch: true});
          write.currentDocument = {updateTime: doc.updateTime};
          writes.push(write);
        }
      }
      if (writes.length) await db.post(`${DB}:commit`, {writes}, privateOptions());
      total += writes.length; token = body.nextPageToken;
    } while (token);
    let reportToken, reportTotal = 0;
    do {
      const body = (await db.get(`${DB}/communityReports`, privateOptions({pageSize: 100,
        ...(reportToken ? {pageToken: reportToken} : {})}))).body;
      const writes = [];
      for (const raw of body.documents || []) {
        const doc = document(raw);
        if (!doc.data.moderationNextAt) {
          const write = update(doc.id, {moderationNextAt: new Date()}, {patch: true});
          write.currentDocument = {updateTime: doc.updateTime};
          writes.push(write);
        }
      }
      if (writes.length) await db.post(`${DB}:commit`, {writes}, privateOptions());
      reportTotal += writes.length; reportToken = body.nextPageToken;
    } while (reportToken);
    const rulesHash = crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname, '../firebase/firestore.rules'))).digest('hex');
    await db.post(`${DB}:commit`, {writes: [update('communityAutomation/migration',
      {policyVersion: POLICY, rulesSha256: rulesHash, commentsUpdated: total, reportsUpdated: reportTotal},
      {timestamps: ['migratedAt']})]}, privateOptions());
    console.log(`Legacy ranking/consent migration verified: ${total} documents updated; existing votes preserved.`);
    return;
  }
  // The secret setup endpoint checks real provider access, IAM and required indexes.
  if (command === 'verify') {
    phase = 'enabled automatic community configuration';
    const config = document((await db.get(`${DB}/communityConfig/current`, privateOptions())).body)?.data;
    if (!automaticConfiguration(config)) {
      throw new Error('Deploy and verify automatic community before building the new release.');
    }
    url = endpoint(config.moderationEndpoint);
  }
  phase = 'verified legacy migration receipt';
  const migration = document((await db.get(`${DB}/communityAutomation/migration`, privateOptions())).body);
  const sourceHash = crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname, '../firebase/firestore.rules'))).digest('hex');
  if (migration?.data.policyVersion !== POLICY || migration.data.rulesSha256 !== sourceHash) throw new Error('Run the verified migration before enabling automatic publication.');
  phase = 'live Worker, provider, IAM and index verification';
  const verified = await verifyWorkerSetup(url, secrets.SETUP_TOKEN);
  if (verified.ready !== true || verified.project !== PROJECT || verified.policyVersion !== POLICY
    || verified.release !== 'automatic-community-v1') throw new Error('Worker identity/policy mismatch. Nothing enabled.');
  const health = document((await db.get(`${DB}/communityAutomation/health`, privateOptions())).body);
  if (!verifiedHealth(health?.data, url)) throw new Error('Worker health proof is missing, stale or mismatched.');
  if (command === 'verify') {
    const current = document((await db.get(`${DB}/communityConfig/current`, privateOptions())).body)?.data;
    if (!automaticConfiguration(current, url)) throw new Error('Community configuration changed during verification.');
    console.log('Automatic community, current migration, live provider/IAM/indexes and health verified. Configuration was not enabled or changed by this release check.');
    return;
  }
  phase = 'automatic moderation activation and read-back';
  const configured = update('communityConfig/current', {enabled: true, moderationReady: true, rulesVersion: 2,
    operatorType: 'automatic-worker', primaryModeratorUid: null, moderationMode: 'automatic',
    moderationEndpoint: url, acceptedPolicyVersion: POLICY}, {patch: true, timestamps: ['updatedAt']});
  await db.post(`${DB}:commit`, {writes: [configured]}, privateOptions());
  const saved = document((await db.get(`${DB}/communityConfig/current`, privateOptions())).body).data;
  if (!automaticConfiguration(saved, url)) throw new Error('Read-back did not confirm activation.');
  console.log('Automatic server moderation enabled and read back. No per-comment owner approval is required. Device QA and report/support coverage remain required.');
}
module.exports = {endpoint, migratedFields, assertReceipt, verifiedHealth, automaticConfiguration};
if (require.main === module) run(process.argv.slice(2)).catch(error => {
  const status = Number.isInteger(error.status) ? ` (HTTP ${error.status})` : '';
  const code = typeof error.code === 'string' && /^(?:WORKER_[A-Z_]+|EPROTO|ECONNRESET|ECONNABORTED|EPIPE|EAI_AGAIN|ENOTFOUND|ETIMEDOUT|CERT_HAS_EXPIRED|ERR_TLS_CERT_ALTNAME_INVALID)$/.test(error.code)
    ? ` [${error.code}]` : '';
  const detail = workerFailureDetails(error);
  const check = detail ? ` Check: ${detail.check}; ${detail.upstreamCode}${detail.upstreamStatus ? `; upstream HTTP ${detail.upstreamStatus}` : ''}.` : '';
  console.error(`Automation setup stopped during: ${phase}${status}${code}.${check} No completion verified; no credentials were printed.`);
  process.exitCode = 1;
});
