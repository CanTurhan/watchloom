'use strict';
// Reuse the installed official Firebase CLI's signed-in account in memory.
// Never print/persist credentials, link billing, or enable a paid service.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

function assertSpark(info) {
  if (!info || info.billingEnabled !== false || info.billingAccountName) {
    throw new Error('BILLING_LINKED');
  }
}
function safeError(error) {
  // Print the server's explanation, never its request/headers or token object.
  const body = error.context?.body?.error;
  const message = String(body?.message || error.message || error.code || error.name)
    .replace(/\u001b\[[0-9;]*m/g, '')
    .replace(/https?:\/\/[^\s)]+/g, value => value.split('?')[0])
    .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
    .replace(/(?:ya29\.|1\/\/)[A-Za-z0-9_.-]+/g, '[REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[REDACTED]')
    .replace(/((?:access_token|refresh_token|id_token|client_secret)["']?\s*[:=]\s*["']?)[^\s,"'&}]+/gi, '$1[REDACTED]');
  const reason = body?.details?.find(item => typeof item.reason === 'string')?.reason;
  const code = body?.status || reason || error.original?.code || error.code;
  return [error.watchloomPhase, error.status && `HTTP ${error.status}`, code, message.slice(0, 1500)]
    .filter(Boolean).join(' · ');
}
async function atPhase(label, action) {
  try { return await action(); }
  catch (error) { error.watchloomPhase = label; throw error; }
}
function cliRoot() {
  let folder = path.dirname(fs.realpathSync(execFileSync('which', ['firebase'], {encoding: 'utf8'}).trim()));
  for (let depth = 0; depth < 8; depth++, folder = path.dirname(folder)) {
    for (const relative of ['package.json', 'libexec/lib/node_modules/firebase-tools/package.json', 'lib/node_modules/firebase-tools/package.json']) {
      const file = path.join(folder, relative);
      if (fs.existsSync(file) && JSON.parse(fs.readFileSync(file)).name === 'firebase-tools') return path.dirname(file);
    }
  }
  throw new Error('CLI_NOT_FOUND');
}
async function check(project, prepareFirestore = false) {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)) throw new Error('INVALID_PROJECT');
  const root = cliRoot();
  const auth = require(path.join(root, 'lib/auth'));
  const account = auth.getProjectDefaultAccount(path.resolve(__dirname, '..')) || auth.getGlobalDefaultAccount();
  if (!account) throw new Error('LOGIN_REQUIRED');
  await atPhase('Firebase CLI authentication', () =>
    require(path.join(root, 'lib/requireAuth')).requireAuth({project, nonInteractive: true, ...account}));
  const {Client} = require(path.join(root, 'lib/apiv2'));
  const api = require(path.join(root, 'lib/api'));
  const client = new Client({urlPrefix: api.cloudbillingOrigin(), apiVersion: 'v1'});
  const utils = require(path.join(root, 'lib/utils'));
  const info = (await atPhase('Spark billing lookup', () =>
    client.get(utils.endpoint(['projects', project, 'billingInfo'])))).body;
  assertSpark(info);
  console.log(`${project}: no billing account linked; Spark-only deployment permitted.`);
  if (prepareFirestore) {
    await atPhase('Firestore API activation', () =>
      require(path.join(root, 'lib/ensureApiEnabled')).ensure(
        project, 'firestore.googleapis.com', 'watchloom', false));
    console.log(`${project}: Firestore API is ready; billing remains unlinked.`);
  }
  return {root};
}
module.exports = {assertSpark, safeError, check};
if (require.main === module) {
  check(process.argv[2] || '', process.argv[3] === '--enable-firestore').catch(error => {
    console.error(error.message === 'BILLING_LINKED'
      ? 'Stopped: a billing account is linked or active. Select the Spark plan in Firebase Console before continuing.'
      : `Stopped: ${safeError(error)}`);
    process.exitCode = 1;
  });
}
