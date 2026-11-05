'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {assertSpark, safeError} = require('./check_firebase_spark.cjs');

test('only an explicit no-billing response permits deployment', () => {
  assert.doesNotThrow(() => assertSpark({billingEnabled: false, billingAccountName: ''}));
  for (const info of [null, {}, {billingEnabled: true}, {billingEnabled: false, billingAccountName: 'billingAccounts/example'}]) {
    assert.throws(() => assertSpark(info), /BILLING_LINKED/);
  }
});

test('an API failure explains the stage and server reason without dumping credentials', () => {
  const error = Object.assign(new Error('request failed'), {
    status: 403, watchloomPhase: 'Spark billing lookup',
    context: {body: {error: {status: 'PERMISSION_DENIED', message: 'Cloud Billing API is disabled.'}},
      request: {headers: {Authorization: 'private-authorization-header'}}},
  });
  const message = safeError(error);
  assert.match(message, /Spark billing lookup.*HTTP 403.*PERMISSION_DENIED.*API is disabled/);
  assert.doesNotMatch(message, /private-authorization-header/);
});

test('token values and URL query parameters are redacted in error messages', () => {
  const message = safeError(new Error('https://example.test/token?secret=url-secret Bearer header-secret ya29.access-secret 1//refresh-secret access_token=access-secret refresh_token="refresh-secret" id_token=id-secret client_secret=client-secret'));
  for (const secret of ['url-secret', 'header-secret', 'access-secret', 'refresh-secret', 'id-secret', 'client-secret']) {
    assert.ok(!message.includes(secret), secret);
  }
});
