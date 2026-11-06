'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {safeProviderCode, safeNetworkCode, publicNetworkDetails} = require('./community_diagnostics.cjs');
test('diagnostics expose only whitelisted provider codes, never messages, identifiers or tokens', () => {
  const secret = 'private-token-do-not-print';
  assert.equal(safeProviderCode({error: {code: 'insufficient_quota', message: secret}}), 'insufficient_quota');
  assert.equal(safeProviderCode({error: {status: 'PERMISSION_DENIED', details: [{reason: 'SERVICE_DISABLED', metadata: {secret}}]}}), 'SERVICE_DISABLED');
  for (const data of [{error: secret}, {error: {code: secret, type: secret, message: secret}},
    {error: {details: [{reason: secret}]}}, null, {}]) {
    const code = safeProviderCode(data);
    assert.equal(code, 'UPSTREAM_ERROR'); assert.ok(!code.includes(secret));
  }
});
test('known missing Auth identity is distinguishable without copying provider text', () => {
  assert.equal(safeProviderCode({error: {message: 'USER_NOT_FOUND'}}), 'USER_NOT_FOUND');
  assert.equal(safeProviderCode({error: 'invalid_grant', error_description: 'private details'}), 'invalid_grant');
});
test('network diagnostics reject arbitrary error messages and unrecognized codes', () => {
  assert.equal(safeNetworkCode({cause: {code: 'ENOTFOUND'}, message: 'private'}), 'ENOTFOUND');
  assert.equal(safeNetworkCode({name: 'TimeoutError'}), 'TimeoutError');
  assert.equal(safeNetworkCode({code: 'Bearer private-key', message: 'private'}), 'NETWORK_ERROR');
});
test('index readiness is reported without its creation URL and malformed details stay opaque', () => {
  assert.equal(safeProviderCode({error: {status: 'FAILED_PRECONDITION',
    message: 'The query requires an index: https://private.example/?secret=hidden'}}), 'INDEX_NOT_READY');
  assert.equal(safeProviderCode({error: {details: {find: 'private'}, message: 'hidden'}}), 'UPSTREAM_ERROR');
});
test('TLS, aggregate network failures and rejected redirects expose only fixed codes', () => {
  assert.equal(safeNetworkCode({cause: {code: 'ERR_SSL_SSLV3_ALERT_HANDSHAKE_FAILURE'}}), 'ERR_SSL_SSLV3_ALERT_HANDSHAKE_FAILURE');
  assert.equal(safeNetworkCode({cause: {errors: [{code: 'ENETUNREACH'}]}}), 'ENETUNREACH');
  assert.equal(safeNetworkCode({cause: {message: 'unexpected redirect'}}), 'REDIRECT_REJECTED');
  assert.equal(safeNetworkCode({cause: {code: 'sk-private-key', message: 'private token'}}), 'NETWORK_ERROR');
});
test('public network error details remove proxy credentials, tokens and control characters', () => {
  const text = JSON.stringify(publicNetworkDetails({message: 'write EPROTO https://user:password@proxy.test/path\n',
    cause: {message: 'Bearer private-value sk-' + 'x'.repeat(30)}}));
  assert.ok(text.includes('EPROTO'));
  for (const value of ['password', 'user:', 'private-value', 'x'.repeat(30), '\\n']) assert.ok(!text.includes(value));
});
