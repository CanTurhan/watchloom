'use strict';
// Uses the owner's existing Firebase CLI login. Apple secrets are read locally,
// sent only to Google's provider endpoint and never logged or copied into source.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {createInterface} = require('node:readline/promises');
const {check} = require('./check_firebase_spark.cjs');
const ROOT = path.resolve(__dirname, '..');
const PROJECT = 'watchloom-canturhan';
const BUNDLE = 'com.canturhan.watchloom';
const TEAM = 'GC8Z24R23C';

function privateOptions(queryParams) {
  return {skipLog: {body: true, resBody: true, queryParams: true}, ...(queryParams ? {queryParams} : {})};
}
function configuration({serviceId, keyId, privateKey}, previous = null) {
  if (!serviceId.startsWith(`${BUNDLE}.`) || !/^[A-Za-z0-9.-]+$/.test(serviceId)) {
    throw new Error('Use the Service ID registered specifically for Watchloom, for example com.canturhan.watchloom.auth.');
  }
  if (!/^[A-Z0-9]{10}$/.test(keyId)) throw new Error('Apple Key ID must contain 10 uppercase letters/digits.');
  if (previous?.clientId && previous.clientId !== serviceId) {
    throw new Error('Apple already uses a different Service ID. Inspect the existing provider before changing it.');
  }
  try {
    if (!privateKey.startsWith('-----BEGIN PRIVATE KEY-----')) throw new Error();
    const key = crypto.createPrivateKey(privateKey);
    if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') throw new Error();
  } catch (_) {
    throw new Error('The selected file must be an Apple Sign in with Apple .p8 P-256 private key.');
  }
  return {
    enabled: true, clientId: serviceId,
    appleSignInConfig: {
      bundleIds: [...new Set([...(previous?.appleSignInConfig?.bundleIds || []), BUNDLE])],
      codeFlowConfig: {teamId: TEAM, keyId, privateKey},
    },
  };
}
async function getProvider(client) {
  try {
    return (await client.get(`/projects/${PROJECT}/defaultSupportedIdpConfigs/apple.com`, privateOptions())).body;
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}
async function saveProvider(client, values, previous) {
  const config = configuration(values, previous);
  if (previous) {
    await client.patch(`/projects/${PROJECT}/defaultSupportedIdpConfigs/apple.com`, config,
      privateOptions({updateMask: 'enabled,clientId,appleSignInConfig'}));
  } else {
    await client.post(`/projects/${PROJECT}/defaultSupportedIdpConfigs`, config,
      privateOptions({idpId: 'apple.com'}));
  }
  // A readback verifies saved public settings; real-device sign-in/revocation
  // is still required to prove the Apple key and portal associations work.
  const saved = await getProvider(client);
  const flow = saved?.appleSignInConfig?.codeFlowConfig;
  if (!saved?.enabled || saved.clientId !== values.serviceId || flow?.teamId !== TEAM || flow?.keyId !== values.keyId ||
      !saved.appleSignInConfig?.bundleIds?.includes(BUNDLE)) {
    throw new Error('Provider write completed but the expected settings were not verified. Inspect Firebase Console.');
  }
  return saved;
}
function summarize(provider) {
  const flow = provider?.appleSignInConfig?.codeFlowConfig;
  return {enabled: provider?.enabled === true, serviceId: provider?.clientId || null,
    expectedTeam: flow?.teamId === TEAM, keyIdPresent: Boolean(flow?.keyId),
    expectedBundle: provider?.appleSignInConfig?.bundleIds?.includes(BUNDLE) === true};
}
async function main() {
  const action = process.argv[2] || '--check';
  if (!['--check', '--configure'].includes(action) || process.argv.length > 3) {
    throw new Error('Usage: node scripts/configure_firebase_apple.cjs [--check|--configure]');
  }
  const project = execFileSync('plutil', ['-extract', 'PROJECT_ID', 'raw', '-o', '-',
    path.join(ROOT, 'ios/Runner/GoogleService-Info.plist')], {encoding: 'utf8'}).trim();
  if (project !== PROJECT) throw new Error('The native Firebase project does not match Watchloom. Nothing changed.');
  const {root} = await check(PROJECT);
  const {Client} = require(path.join(root, 'lib/apiv2'));
  const client = new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'admin/v2'});
  const previous = await getProvider(client);
  if (action === '--check') {
    const state = summarize(previous);
    console.log(JSON.stringify(state, null, 2));
    if (!Object.entries(state).every(([name, value]) => name === 'serviceId' ? Boolean(value) : value === true)) {
      throw new Error('Apple provider setup is incomplete. Complete the Apple portal steps, then use --configure.');
    }
    console.log('Apple provider settings are present. Device sign-in, Hide My Email and deletion tests remain required.');
    return;
  }
  if (!process.stdin.isTTY) throw new Error('Run --configure directly in your Mac Terminal for local input.');
  const input = createInterface({input: process.stdin, output: process.stdout});
  try {
    const serviceId = (await input.question('Registered Watchloom Service ID [com.canturhan.watchloom.auth]: ')).trim() || `${BUNDLE}.auth`;
    const keyId = (await input.question('Sign in with Apple Key ID: ')).trim();
    const answer = (await input.question('Local .p8 file path (outside the repository): ')).trim();
    const keyPath = fs.realpathSync(answer.startsWith('~/') ? path.join(require('node:os').homedir(), answer.slice(2)) : answer);
    if (keyPath.startsWith(`${ROOT}${path.sep}`)) throw new Error('Keep the Apple key outside the repository, then retry.');
    const stat = fs.statSync(keyPath);
    if (!stat.isFile() || stat.size > 16384 || path.extname(keyPath) !== '.p8') throw new Error('Select the downloaded Sign in with Apple .p8 key.');
    fs.chmodSync(keyPath, 0o600);
    const privateKey = fs.readFileSync(keyPath, 'utf8').trim();
    const saved = await saveProvider(client, {serviceId, keyId, privateKey}, previous);
    console.log(JSON.stringify(summarize(saved), null, 2));
    console.log('Watchloom Apple provider configured and read back. No key was copied into the app/repository; device tests are next.');
  } finally {
    input.close();
  }
}

module.exports = {configuration, saveProvider, summarize};
if (require.main === module) {
  main().catch(error => {
    // API validation responses can contain submitted data: never print their
    // body, message, stack or the request object in this secret-bearing helper.
    const status = error.context?.body?.error?.status;
    console.error(error.context || error.original
      ? `Apple configuration stopped (${error.status || 'network'} ${status || error.original?.code || ''}). Check provider permissions/network in Firebase Console.`
      : error.code ? `Apple configuration stopped (${error.code}). Check the local key path and permissions.`
      : error.message);
    process.exitCode = 1;
  });
}
