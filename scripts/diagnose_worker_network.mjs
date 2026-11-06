#!/usr/bin/env node
// Public network checks only. No keys, tokens, response bodies or proxy URLs printed.
import {lookup} from 'node:dns/promises';
import {connect} from 'node:tls';
import {get, Agent} from 'node:https';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createRequire} from 'node:module';
import {PROJECT, POLICY, RELEASE} from '../server/community-worker/src/policy.mjs';
import {limitedText} from '../server/community-worker/src/google.mjs';
const require = createRequire(import.meta.url);
const {endpoint} = require('./configure_community_automation.cjs');
const {safeNetworkCode, publicNetworkDetails, networkEnvironment} = require('./community_diagnostics.cjs');
const execute = promisify(execFile);
const emit = value => process.stdout.write(JSON.stringify(value) + '\n');
const results = [];
const validBody = text => {
  let body; try {body = JSON.parse(text);} catch {}
  return body?.project === PROJECT && body?.policyVersion === POLICY && body?.release === RELEASE;
};
const health = (status, body) => ({status: status === 200 && validBody(body) ? 'passed' : 'failed', httpStatus: status});
async function probe(stage, action) {
  emit({stage, status: 'checking'});
  try {
    const result = await action(); results.push({stage, ...result}); emit({stage, ...result});
    return result.status === 'passed';
  } catch (error) {
    const result = {stage, status: 'failed', code: safeNetworkCode(error), ...publicNetworkDetails(error)};
    results.push(result); emit(result); return false;
  }
}
function nativeHealth(url, agent) {
  return new Promise((resolve, reject) => {
    const request = get(url, {headers: {Accept: 'application/json'}, rejectUnauthorized: true,
      signal: AbortSignal.timeout(15000), ...(agent ? {agent} : {})}, response => {
      const parts = []; let size = 0;
      response.on('data', part => {
        size += part.length;
        if (size > 64 * 1024) {request.destroy(new Error('Public response too large')); return;}
        parts.push(part);
      });
      response.once('end', () => resolve(health(response.statusCode, Buffer.concat(parts).toString('utf8'))));
      response.once('error', reject);
    });
    request.once('error', reject);
  });
}
try {
  const root = endpoint(process.argv[2]), host = new URL(root).hostname, url = new URL('/health', root);
  const environment = networkEnvironment();
  emit({stage: 'network_environment', nodeVersion: process.version, opensslVersion: process.versions.openssl, ...environment});
  if (!environment.certificateValidationEnabled) throw new Error('Restore certificate validation before network checks');
  const dnsReady = await probe('worker_dns', async () => {
    const addresses = await lookup(host, {all: true});
    return {status: 'passed', families: [...new Set(addresses.map(a => a.family))]};
  });
  if (!dnsReady) process.exitCode = 1;
  else {
    await probe('worker_tls', async () => {
      const protocol = await new Promise((resolve, reject) => {
        const socket = connect({host, port: 443, servername: host, rejectUnauthorized: true}, () => {
          const value = socket.getProtocol(); socket.destroy(); resolve(value);
        });
        socket.setTimeout(10000, () => {
          const error = new Error(); error.code = 'ETIMEDOUT'; socket.destroy(error);
        });
        socket.once('error', reject);
      });
      return {status: 'passed', protocol};
    });
    await probe('worker_https', () => nativeHealth(url));
    // Diagnostic comparison only. The deployment/app transport is not changed.
    await probe('worker_https_direct', async () => {
      const agent = new Agent({keepAlive: false, maxCachedSessions: 0, proxyEnv: {}});
      try {return await nativeHealth(url, agent);} finally {agent.destroy();}
    });
    await probe('worker_public_health', async () => {
      const response = await fetch(url, {redirect: 'manual', signal: AbortSignal.timeout(15000)});
      if (response.status >= 300 && response.status < 400) {
        let code = 'UNEXPECTED_REDIRECT';
        try {
          const location = new URL(response.headers.get('Location'), root);
          if (location.hostname.endsWith('.cloudflareaccess.com')) code = 'CLOUDFLARE_ACCESS_REQUIRED';
        } catch {}
        return {status: 'failed', httpStatus: response.status, code};
      }
      return health(response.status, await limitedText(response, 64 * 1024));
    });
    // curl's user config is disabled. Never follow redirects, disable certificate
    // verification, print response text or pass credentials.
    for (const [stage, mode] of [['worker_curl', null], ['worker_curl_http1', '--http1.1']]) {
      await probe(stage, async () => {
        const args = ['--disable', '--silent', '--show-error', '--proto', '=https',
          '--max-redirs', '0', '--connect-timeout', '8', '--max-time', '15', '--max-filesize', '65536',
          '--header', 'Accept: application/json', '--write-out', '\n%{http_code}', ...(mode ? [mode] : []), url.href];
        let output;
        try {output = await execute('/usr/bin/curl', args, {timeout: 17000, maxBuffer: 70 * 1024});}
        catch (error) {
          // execFile's default message includes its entire command. Keep only
          // curl's bounded public stderr and fixed numeric exit status.
          const value = new Error(typeof error.stderr === 'string' ? error.stderr : 'System HTTPS request failed');
          value.code = 'CURL_' + (Number.isInteger(error.code) ? error.code : 'ERROR'); throw value;
        }
        const split = output.stdout.lastIndexOf('\n');
        const status = Number(output.stdout.slice(split + 1));
        return health(status, output.stdout.slice(0, split));
      });
    }
    const defaultReady = results.some(r => r.stage === 'worker_public_health' && r.status === 'passed');
    const anotherReady = results.some(r => ['worker_https_direct', 'worker_curl', 'worker_curl_http1'].includes(r.stage) && r.status === 'passed');
    emit({result: defaultReady ? 'worker_public_health_verified'
      : anotherReady ? 'client_transport_difference_identified' : 'worker_http_unreachable', applicationCredentialsUsed: false});
    process.exitCode = defaultReady ? 0 : 1;
  }
} catch (error) {
  emit({stage: 'network_configuration', status: 'failed', code: safeNetworkCode(error), ...publicNetworkDetails(error)});
  process.exitCode = 1;
}
