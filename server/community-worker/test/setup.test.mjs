import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.mjs';
import {upstreamDiagnostic, setupFailure, readSetupFailure} from '../src/diagnostics.mjs';

test('server diagnostics retain only approved upstream codes and never copy private provider content', () => {
  const privateValue = 'synthetic-private-provider-message';
  assert.deepEqual(upstreamDiagnostic({error: {code: 'invalid_api_key', message: privateValue}}, 401), {code: 'invalid_api_key', status: 401});
  assert.deepEqual(upstreamDiagnostic({error: {status: 'PERMISSION_DENIED', details: [{reason: 'SERVICE_DISABLED', metadata: {privateValue}}]}}, 403),
    {code: 'SERVICE_DISABLED', status: 403});
  assert.equal(upstreamDiagnostic({error: {status: 'FAILED_PRECONDITION', message: 'index https://private.test/?key=' + privateValue}}, 400).code, 'INDEX_NOT_READY');
  for (const data of [null, {error: privateValue}, {error: {details: privateValue, code: privateValue, message: privateValue}}]) {
    assert.deepEqual(upstreamDiagnostic(data, 503), {code: 'UPSTREAM_HTTP_ERROR', status: 503});
  }
  assert.equal(setupFailure('google_oauth', {name: '__proto__', message: privateValue}).code, 'CHECK_FAILED');
});
test('the owner client accepts only current-project diagnostics with fixed stage/code and numeric status', () => {
  const privateValue = 'synthetic-private-provider-message';
  const failure = setupFailure('health_write', {upstreamCode: 'PERMISSION_DENIED', upstreamStatus: 403, message: privateValue});
  assert.deepEqual(readSetupFailure({...failure, privateValue}), {stage: 'health_write', code: 'PERMISSION_DENIED', upstreamStatus: 403});
  assert.ok(!JSON.stringify(failure).includes(privateValue));
  for (const value of [null, {}, {...failure, stage: privateValue}, {...failure, code: privateValue},
    {...failure, project: 'puzzle-music-sort-canturhan'}, {...failure, release: 'old'}, {...failure, policyVersion: 'old'},
    {...failure, ready: true}]) assert.equal(readSetupFailure(value), null);
  assert.deepEqual(readSetupFailure({...failure, upstreamStatus: privateValue}), {stage: 'health_write', code: 'PERMISSION_DENIED'});
});
test('setup diagnostics remain owner-only even when the server credential is missing or malformed', async () => {
  const env = {SETUP_TOKEN: 'd'.repeat(64)};
  for (const authorization of [null, 'Bearer incorrect-token', 'Bearer ' + 'c'.repeat(64)]) {
    const response = await worker.fetch(new Request('https://watchloom-community.example.workers.dev/v1/verify-setup',
      {method: 'POST', headers: {'Content-Type': 'application/json', ...(authorization ? {Authorization: authorization} : {})}, body: '{}'}), env);
    assert.equal(response.status, 401); assert.deepEqual(await response.json(), {error: 'unauthorized'});
  }
});
