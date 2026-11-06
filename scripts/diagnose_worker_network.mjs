#!/usr/bin/env node
// Public DNS/TLS/health checks only; no credentials are read or transmitted.
import {lookup} from 'node:dns/promises';
import {connect} from 'node:tls';
import {get} from 'node:https';
import {createRequire} from 'node:module';
import {PROJECT, POLICY, RELEASE} from '../server/community-worker/src/policy.mjs';
import {limitedText} from '../server/community-worker/src/google.mjs';
const require = createRequire(import.meta.url);
const {endpoint} = require('./configure_community_automation.cjs');
const {safeNetworkCode, publicNetworkDetails} = require('./community_diagnostics.cjs');
const emit = value => process.stdout.write(JSON.stringify(value) + '\n');
let stage = 'endpoint';
try {
  const root = endpoint(process.argv[2]), host = new URL(root).hostname;
  stage = 'worker_dns'; emit({stage, status: 'checking'});
  const addresses = await lookup(host, {all: true});
  emit({stage, status: 'passed', families: [...new Set(addresses.map(a => a.family))]});
  stage = 'worker_tls'; emit({stage, status: 'checking'});
  const protocol = await new Promise((resolve, reject) => {
    const socket = connect({host, port: 443, servername: host, rejectUnauthorized: true}, () => {
      const value = socket.getProtocol(); socket.destroy(); resolve(value);
    });
    socket.setTimeout(10000, () => {
      const error = new Error(); error.code = 'ETIMEDOUT'; socket.destroy(error);
    });
    socket.once('error', reject);
  });
  emit({stage, status: 'passed', protocol});
  stage = 'worker_https'; emit({stage, status: 'checking'});
  const native = await new Promise((resolve, reject) => {
    const request = get(new URL('/health', root), {headers: {Accept: 'application/json'}}, response => {
      const parts = []; let size = 0;
      response.on('data', part => {
        size += part.length;
        if (size > 64 * 1024) {request.destroy(new Error('Public response too large')); return;}
        parts.push(part);
      });
      response.once('end', () => resolve({status: response.statusCode, body: Buffer.concat(parts).toString('utf8')}));
      response.once('error', reject);
    });
    request.setTimeout(15000, () => {
      const error = new Error('Public HTTPS request timed out'); error.code = 'ETIMEDOUT'; request.destroy(error);
    });
    request.once('error', reject);
  });
  let nativeBody; try {nativeBody = JSON.parse(native.body);} catch {}
  const nativeValid = native.status === 200 && nativeBody?.project === PROJECT
    && nativeBody?.policyVersion === POLICY && nativeBody?.release === RELEASE;
  emit({stage, status: nativeValid ? 'passed' : 'failed', httpStatus: native.status});
  stage = 'worker_public_health'; emit({stage, status: 'checking'});
  const response = await fetch(new URL('/health', root), {redirect: 'manual', signal: AbortSignal.timeout(15000)});
  if (response.status >= 300 && response.status < 400) {
    let code = 'UNEXPECTED_REDIRECT';
    try {
      const location = new URL(response.headers.get('Location'), root);
      if (location.hostname.endsWith('.cloudflareaccess.com')) code = 'CLOUDFLARE_ACCESS_REQUIRED';
    } catch {}
    emit({stage, status: 'failed', httpStatus: response.status, code}); process.exitCode = 1;
  } else if (!response.ok) {
    emit({stage, status: 'failed', httpStatus: response.status, code: 'WORKER_HTTP_ERROR'}); process.exitCode = 1;
  } else {
    let body; try {body = JSON.parse(await limitedText(response, 64 * 1024));} catch {}
    const valid = body?.project === PROJECT && body?.policyVersion === POLICY && body?.release === RELEASE;
    emit({stage, status: valid ? 'passed' : 'failed', httpStatus: response.status});
    process.exitCode = valid ? 0 : 1;
  }
} catch (error) {
  emit({stage, status: 'failed', code: safeNetworkCode(error), ...publicNetworkDetails(error)}); process.exitCode = 1;
}
