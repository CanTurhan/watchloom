'use strict';
// Owner tooling only. Native HTTPS avoids the observed Node fetch TLS failure.
const https = require('node:https');
const {safeNetworkCode} = require('./community_diagnostics.cjs');
const MAXIMUM_BYTES = 64 * 1024;
const TRANSIENT = new Set(['EPROTO', 'ECONNRESET', 'ECONNABORTED', 'EPIPE', 'EAI_AGAIN']);

function endpoint(value) {
  let url; try { url = new URL(value); } catch { throw new Error('Use the deployed HTTPS workers.dev root URL.'); }
  if (url.protocol !== 'https:' || !/^[a-z0-9-]+\.[a-z0-9-]+\.workers\.dev$/.test(url.hostname)
    || url.username || url.password || url.port || url.search || url.hash || url.pathname !== '/') {
    throw new Error('Use the deployed HTTPS workers.dev root URL, without credentials, path or parameters.');
  }
  return url.href;
}
class WorkerVerificationError extends Error {
  constructor(code, status) {
    super(`Worker setup verification failed (${code}).`);
    this.name = 'WorkerVerificationError'; this.code = code;
    if (Number.isInteger(status)) this.status = status;
  }
}
const networkError = error => new WorkerVerificationError(safeNetworkCode(error));

function requestOnce(root, token, timeout, request, identity) {
  return new Promise((resolve, reject) => {
    let outgoing, incoming, completed = false;
    const finish = (error, value) => {
      if (completed) return;
      completed = true; clearTimeout(timer);
      if (error) { incoming?.destroy(); outgoing?.destroy(); reject(error); }
      else resolve(value);
    };
    const timer = setTimeout(() => finish(new WorkerVerificationError('WORKER_TIMEOUT')), timeout);
    try {
      outgoing = request(new URL('/v1/verify-setup', root), {
        method: 'POST', rejectUnauthorized: true,
        headers: {Authorization: `Bearer ${token}`, Accept: 'application/json',
          'Content-Type': 'application/json', 'Content-Length': '2'},
      }, response => {
        incoming = response;
        response.once('error', error => finish(networkError(error)));
        response.once('aborted', () => finish(new WorkerVerificationError('WORKER_INCOMPLETE_RESPONSE')));
        response.once('close', () => {
          if (!completed) finish(new WorkerVerificationError('WORKER_INCOMPLETE_RESPONSE'));
        });
        // Native HTTPS never follows redirects; the setup token stays on this host.
        const status = response.statusCode;
        if (status !== 200) {
          finish(new WorkerVerificationError(status >= 300 && status < 400
            ? 'WORKER_REDIRECT_REJECTED' : 'WORKER_HTTP_ERROR', status)); return;
        }
        if (!/^application\/json(?:\s*;|\s*$)/i.test(response.headers['content-type'] || '')) {
          finish(new WorkerVerificationError('WORKER_INVALID_RESPONSE')); return;
        }
        if (Number(response.headers['content-length']) > MAXIMUM_BYTES) {
          finish(new WorkerVerificationError('WORKER_RESPONSE_TOO_LARGE')); return;
        }
        const chunks = []; let size = 0;
        response.on('data', chunk => {
          if (completed) return;
          const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
          size += bytes.length;
          if (size > MAXIMUM_BYTES) { finish(new WorkerVerificationError('WORKER_RESPONSE_TOO_LARGE')); return; }
          chunks.push(bytes);
        });
        response.once('end', () => {
          if (completed) return;
          let data;
          try { data = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(Buffer.concat(chunks))); }
          catch { finish(new WorkerVerificationError('WORKER_INVALID_RESPONSE')); return; }
          if (data?.ready !== true || data.project !== identity.PROJECT || data.policyVersion !== identity.POLICY
            || data.release !== identity.RELEASE) {
            finish(new WorkerVerificationError('WORKER_IDENTITY_MISMATCH')); return;
          }
          finish(null, {ready: true, project: data.project, policyVersion: data.policyVersion, release: data.release});
        });
      });
      outgoing.once('error', error => finish(networkError(error)));
      outgoing.end('{}');
    } catch (error) { finish(networkError(error)); }
  });
}

function createWorkerClient({request = https.request, timeoutMs = 45000,
  wait = ms => new Promise(resolve => setTimeout(resolve, ms))} = {}) {
  return async function verify(root, token) {
    const normalized = endpoint(root);
    if (!/^[a-f0-9]{64}$/.test(token || '') || process.env.NODE_TLS_REJECT_UNAUTHORIZED === '0') {
      throw new WorkerVerificationError('WORKER_UNSAFE_CONFIGURATION');
    }
    const identity = await import('../server/community-worker/src/policy.mjs');
    const deadline = Date.now() + Math.min(45000, Math.max(1, timeoutMs));
    for (let attempt = 0; attempt < 2; attempt++) {
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new WorkerVerificationError('WORKER_TIMEOUT');
      try { return await requestOnce(normalized, token, remaining, request, identity); }
      catch (error) {
        // Synthetic verification is idempotent. Never retry certificate errors,
        // HTTP/provider failures, mismatched identity, redirects or invalid JSON.
        if (attempt !== 0 || !TRANSIENT.has(error.code) || deadline - Date.now() <= 150) throw error;
        await wait(150);
      }
    }
  };
}
module.exports = {endpoint, createWorkerClient, verifyWorkerSetup: createWorkerClient()};
