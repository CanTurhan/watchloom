'use strict';
// Reuse Firebase CLI credentials in memory. Never send email or log secrets.
const path = require('node:path');
const assert = require('node:assert/strict');
const {check} = require('./check_firebase_spark.cjs');
const project = 'watchloom-canturhan';
const templates = ['verifyEmailTemplate', 'resetPasswordTemplate', 'changeEmailTemplate'];
const fields = templates.map(key => `notification.sendEmail.${key}.senderDisplayName`);

function protectedConfig(config) {
  const copy = structuredClone(config);
  delete copy.updateTime;
  for (const key of templates) {
    const template = copy.notification?.sendEmail?.[key];
    if (template) {
      delete template.senderDisplayName;
      delete template.customized; // Server-computed template metadata.
    }
  }
  return copy;
}

async function main() {
  const mode = process.argv[2] || '--check';
  if (!['--check', '--apply'].includes(mode)) throw new Error('INVALID_MODE');
  const {root} = await check(project);
  const {Client} = require(path.join(root, 'lib/apiv2'));
  const client = new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'v2'});
  const endpoint = `/projects/${project}/config`;
  const before = (await client.get(endpoint)).body;
  if (before.name !== `projects/${project}/config` && before.name !== 'projects/157774090938/config') {
    throw new Error('PROJECT_GUARD_FAILED');
  }
  for (const key of templates) {
    const template = before.notification?.sendEmail?.[key];
    if (!template?.body?.includes('%LINK%') || !template.subject?.includes('%APP_NAME%')) {
      throw new Error('UNEXPECTED_TEMPLATE_REVIEW_REQUIRED');
    }
  }
  const changed = templates.filter(key => before.notification.sendEmail[key].senderDisplayName !== 'Watchloom');
  console.log(JSON.stringify({project, mode, senderDisplayName: 'Watchloom', templatesToUpdate: changed}));
  if (mode === '--check' || changed.length === 0) return;
  // Field masks prevent replacing nested templates, SMTP, action links or Auth settings.
  await client.patch(endpoint, {name: before.name, notification: {sendEmail:
    Object.fromEntries(templates.map(key => [key, {senderDisplayName: 'Watchloom'}]))}},
  {queryParams: {updateMask: fields.join(',')}});
  const after = (await client.get(endpoint)).body;
  assert.deepEqual(protectedConfig(after), protectedConfig(before), 'Unrelated Auth configuration changed; inspect privately.');
  for (const key of templates) assert.equal(after.notification.sendEmail[key].senderDisplayName, 'Watchloom');
  console.log('Verified: all three sender names are Watchloom; protected Auth configuration is unchanged. No email was sent.');
}
main().catch(error => {
  // Never serialize request/config/SDK error objects: they may contain credentials.
  console.error(`Watchloom email branding failed (${Number.isInteger(error.status) ? error.status : 'verification-or-access-error'}).`);
  process.exitCode = 1;
});
