'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {generateKeyPairSync} = require('node:crypto');
const {configuration, saveProvider, summarize} = require('./configure_firebase_apple.cjs');
const privateKey = generateKeyPairSync('ec', {namedCurve: 'prime256v1',
  privateKeyEncoding: {type: 'pkcs8', format: 'pem'}, publicKeyEncoding: {type: 'spki', format: 'pem'}}).privateKey;
const values = {serviceId: 'com.canturhan.watchloom.auth', keyId: 'TESTKEY123', privateKey};

test('provider setup rejects unrelated IDs and invalid Apple keys', () => {
  assert.throws(() => configuration({...values, serviceId: 'com.other.app'}), /specifically for Watchloom/);
  assert.throws(() => configuration({...values, keyId: 'bad'}), /Key ID/);
  assert.throws(() => configuration({...values, privateKey: 'secret-is-invalid'}), /P-256/);
  assert.throws(() => configuration(values, {clientId: 'com.other.service'}), /different Service ID/);
});

test('public summaries contain no private key or client secret', () => {
  const configured = configuration(values);
  const summary = summarize({...configured, clientSecret: 'private-client-secret'});
  assert.equal(summary.enabled, true);
  assert.equal(summary.expectedTeam, true);
  assert.ok(!JSON.stringify(summary).includes('PRIVATE KEY'));
  assert.ok(!JSON.stringify(summary).includes('private-client-secret'));
});

function privateRequest(options) {
  assert.equal(options.skipLog.body, true);
  assert.equal(options.skipLog.resBody, true);
}

test('creating Apple changes only its provider and suppresses request/response body logs', async () => {
  let saved;
  const client = {
    async post(url, body, options) {
      assert.equal(url, '/projects/watchloom-canturhan/defaultSupportedIdpConfigs');
      assert.equal(options.queryParams.idpId, 'apple.com');
      privateRequest(options); saved = body;
    },
    async get(url, options) {
      assert.ok(url.endsWith('/apple.com')); privateRequest(options); return {body: saved};
    },
  };
  const result = await saveProvider(client, values, null);
  assert.equal(result.appleSignInConfig.codeFlowConfig.privateKey, privateKey);
});

test('updating Apple preserves existing allowed bundles and verifies the saved settings', async () => {
  let saved;
  const previous = {clientId: values.serviceId, appleSignInConfig: {bundleIds: ['com.canturhan.watchloom.other']}};
  const client = {
    async patch(url, body, options) {
      assert.ok(url.endsWith('/apple.com')); privateRequest(options);
      assert.equal(options.queryParams.updateMask, 'enabled,clientId,appleSignInConfig'); saved = body;
    },
    async get(url, options) {privateRequest(options); return {body: saved};},
  };
  await saveProvider(client, values, previous);
  assert.deepEqual(saved.appleSignInConfig.bundleIds, ['com.canturhan.watchloom.other', 'com.canturhan.watchloom']);
  client.get = async () => ({body: {...saved, enabled: false}});
  await assert.rejects(saveProvider(client, values, previous), /not verified/);
});
