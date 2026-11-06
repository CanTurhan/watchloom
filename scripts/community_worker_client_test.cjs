'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {EventEmitter} = require('node:events');
const {Readable, PassThrough} = require('node:stream');
const {createWorkerClient} = require('./community_worker_client.cjs');
const ROOT = 'https://watchloom-community.watchloom-canturhan.workers.dev/';
const TOKEN = 'a'.repeat(64); // Synthetic setup token, never a live credential.
const READY = {ready: true, project: 'watchloom-canturhan', policyVersion: '2026-11-06-auto-v1', release: 'automatic-community-v1'};

function transport(scenarios) {
  const calls = [];
  const request = (url, options, callback) => {
    const current = scenarios[calls.length];
    assert.ok(current, 'Unexpected additional network request');
    const outgoing = new EventEmitter(); let incoming;
    const call = {url: url.href, options, destroyed: false}; calls.push(call);
    outgoing.destroy = () => { call.destroyed = true; incoming?.destroy(); };
    outgoing.end = body => {
      call.body = body;
      queueMicrotask(() => {
        if (current.error) {outgoing.emit('error', current.error); return;}
        incoming = current.hang || current.aborted ? new PassThrough()
          : Readable.from(current.chunks || [Buffer.from(current.body ?? JSON.stringify(READY))]);
        incoming.statusCode = current.status || 200;
        incoming.headers = {'content-type': 'application/json; charset=utf-8', ...current.headers};
        callback(incoming);
        if (current.aborted) queueMicrotask(() => incoming.emit('aborted'));
      });
    };
    return outgoing;
  };
  return {calls, verify: createWorkerClient({request, wait: async () => {}})};
}

test('Worker setup uses certificate-verified native HTTPS with a fixed path and header-only credential', async () => {
  const {calls, verify} = transport([{body: JSON.stringify({...READY, extra: 'discarded'})}]);
  assert.deepEqual(await verify(ROOT, TOKEN), READY);
  assert.equal(calls.length, 1);
  const sent = calls[0];
  assert.equal(sent.url, ROOT + 'v1/verify-setup');
  assert.equal(sent.options.method, 'POST');
  assert.equal(sent.options.rejectUnauthorized, true);
  assert.equal(sent.options.headers.Authorization, 'Bearer ' + TOKEN);
  assert.equal(sent.options.headers['Content-Length'], '2');
  assert.equal(sent.body, '{}');
  assert.ok(!sent.url.includes(TOKEN)); assert.ok(!sent.body.includes(TOKEN));
});

test('redirects never forward the setup credential and HTTP failures never copy provider bodies', async () => {
  for (const [status, code] of [[302, 'WORKER_REDIRECT_REJECTED'], [503, 'WORKER_HTTP_ERROR'], [401, 'WORKER_HTTP_ERROR']]) {
    const {calls, verify} = transport([{status, body: 'private-upstream-detail ' + TOKEN,
      headers: {location: 'https://foreign.test/?private-upstream-detail=' + TOKEN}}]);
    await assert.rejects(verify(ROOT, TOKEN), error => {
      assert.equal(error.code, code); assert.equal(error.status, status);
      assert.ok(!error.message.includes(TOKEN)); assert.ok(!error.message.includes('private-upstream-detail'));
      return true;
    });
    assert.equal(calls.length, 1); assert.equal(calls[0].destroyed, true);
  }
});

test('oversized, malformed, non-JSON and invalid UTF-8 Worker responses cannot create a readiness proof', async () => {
  for (const scenario of [
    {headers: {'content-length': '65537'}}, {chunks: [Buffer.alloc(32768), Buffer.alloc(32769)]},
    {body: '{'}, {body: JSON.stringify(READY), headers: {'content-type': 'text/html'}},
    {chunks: [Buffer.from([0xff, 0xfe])]},
  ]) {
    const {calls, verify} = transport([scenario]);
    await assert.rejects(verify(ROOT, TOKEN), error => {
      assert.ok(['WORKER_RESPONSE_TOO_LARGE', 'WORKER_INVALID_RESPONSE'].includes(error.code)); return true;
    });
    assert.equal(calls.length, 1);
  }
});

test('only the current Watchloom project, policy, release and boolean readiness are accepted', async () => {
  for (const result of [{...READY, ready: 'true'}, {...READY, ready: false}, {...READY, project: 'puzzle-music-sort-canturhan'},
    {...READY, policyVersion: 'old'}, {...READY, release: 'other'}, null, [], {}]) {
    const {calls, verify} = transport([{body: JSON.stringify(result)}]);
    await assert.rejects(verify(ROOT, TOKEN), {code: 'WORKER_IDENTITY_MISMATCH'});
    assert.equal(calls.length, 1);
  }
});

test('a transient TLS protocol failure retries once with certificate checks still enabled', async () => {
  const problem = {message: 'tls_validate_record_header:wrong version number:' + TOKEN};
  const recovered = transport([{error: problem}, {}]);
  assert.deepEqual(await recovered.verify(ROOT, TOKEN), READY);
  assert.equal(recovered.calls.length, 2);
  assert.ok(recovered.calls.every(call => call.options.rejectUnauthorized === true));
  const failed = transport([{error: problem}, {error: problem}]);
  await assert.rejects(failed.verify(ROOT, TOKEN), error => {
    assert.equal(error.code, 'EPROTO'); assert.ok(!error.message.includes(TOKEN)); return true;
  });
  assert.equal(failed.calls.length, 2);
});

test('certificate and other permanent network errors stop without a fallback or leaked error text', async () => {
  for (const code of ['CERT_HAS_EXPIRED', 'ERR_TLS_CERT_ALTNAME_INVALID', 'ENOTFOUND']) {
    const {calls, verify} = transport([{error: {code, message: 'Bearer ' + TOKEN}}]);
    await assert.rejects(verify(ROOT, TOKEN), error => {
      assert.equal(error.code, code); assert.ok(!error.message.includes(TOKEN)); return true;
    });
    assert.equal(calls.length, 1);
  }
});

test('an incomplete response or total deadline destroys the connection and never verifies', async () => {
  const interrupted = transport([{aborted: true}]);
  await assert.rejects(interrupted.verify(ROOT, TOKEN), {code: 'WORKER_INCOMPLETE_RESPONSE'});
  assert.equal(interrupted.calls[0].destroyed, true);
  let destroyed = false;
  const verify = createWorkerClient({timeoutMs: 5, request: () => {
    const outgoing = new EventEmitter(); outgoing.end = () => {}; outgoing.destroy = () => {destroyed = true;}; return outgoing;
  }});
  await assert.rejects(verify(ROOT, TOKEN), {code: 'WORKER_TIMEOUT'});
  assert.equal(destroyed, true);
});

test('unsafe URLs, malformed credentials and disabled certificate checks fail before transmission', async () => {
  let requests = 0;
  const verify = createWorkerClient({request: () => {requests++; throw new Error('Unexpected request');}});
  for (const root of ['http://watchloom-community.x.workers.dev/', 'https://foreign.test/',
    ROOT + '?token=hidden', ROOT + 'other', 'https://user:password@watchloom-community.x.workers.dev/']) {
    await assert.rejects(verify(root, TOKEN));
  }
  await assert.rejects(verify(ROOT, 'invalid'), {code: 'WORKER_UNSAFE_CONFIGURATION'});
  const previous = process.env.NODE_TLS_REJECT_UNAUTHORIZED;
  try {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
    await assert.rejects(verify(ROOT, TOKEN), {code: 'WORKER_UNSAFE_CONFIGURATION'});
  } finally {
    if (previous === undefined) delete process.env.NODE_TLS_REJECT_UNAUTHORIZED;
    else process.env.NODE_TLS_REJECT_UNAUTHORIZED = previous;
  }
  assert.equal(requests, 0);
});
