import {PROJECT, uidValid} from './policy.mjs';
import {upstreamDiagnostic} from './diagnostics.mjs';

export class ServiceError extends Error {
  constructor(code = 'service_unavailable', status = 503, upstream) {
    super(code); this.code = code; this.status = status;
    if (upstream) { this.upstreamCode = upstream.code; this.upstreamStatus = upstream.status; }
  }
}
async function providerFailure(response) {
  let data; try { data = JSON.parse(await limitedText(response, 64 * 1024)); } catch {}
  return upstreamDiagnostic(data, response.status);
}
export async function jsonFetch(url, options = {}) {
  const response = await fetch(url, {...options, redirect: 'error', signal: AbortSignal.timeout(8000)});
  if (!response.ok) throw new ServiceError(response.status === 429 ? 'temporarily_busy' : 'service_unavailable', 503,
    await providerFailure(response));
  const body = await limitedText(response, 256 * 1024);
  try { return JSON.parse(body); } catch { throw new ServiceError(); }
}
export async function limitedText(message, maximum) {
  if (!message.body) throw new ServiceError('invalid_request', 400);
  const reader = message.body.getReader();
  const chunks = []; let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.length;
      if (size > maximum) throw new ServiceError('request_too_large', 413);
      chunks.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return new TextDecoder('utf-8', {fatal: true}).decode(bytes);
}
const base64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
const encode = object => base64(new TextEncoder().encode(JSON.stringify(object)));
const bytes = value => Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0));
let credentials, oauth, jwks;
export function account(env) {
  if (env.FIREBASE_PROJECT_ID !== PROJECT) throw new ServiceError();
  if (credentials?.source === env.FIREBASE_SERVICE_ACCOUNT) return credentials.data;
  let data; try { data = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT); } catch { throw new ServiceError(); }
  if (data.project_id !== PROJECT
    || !/^[a-z0-9-]+@watchloom-canturhan\.iam\.gserviceaccount\.com$/.test(data.client_email || '')
    || data.token_uri !== 'https://oauth2.googleapis.com/token'
    || !data.private_key?.startsWith('-----BEGIN PRIVATE KEY-----')) throw new ServiceError();
  credentials = {source: env.FIREBASE_SERVICE_ACCOUNT, data};
  return data;
}
export async function googleToken(env) {
  const data = account(env), now = Math.floor(Date.now() / 1000);
  if (oauth?.email === data.client_email && oauth.source === data.private_key && oauth.until > now + 120) return oauth.token;
  const pem = data.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', bytes(pem), {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign']);
  const unsigned = `${encode({alg: 'RS256', typ: 'JWT'})}.${encode({iss: data.client_email,
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit',
    aud: data.token_uri, iat: now, exp: now + 3600})}`;
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const result = await jsonFetch(data.token_uri, {method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${base64(signature)}`})});
  if (typeof result.access_token !== 'string' || !Number.isFinite(result.expires_in)) throw new ServiceError();
  oauth = {email: data.client_email, source: data.private_key, token: result.access_token, until: now + result.expires_in};
  return oauth.token;
}
export async function lookupUser(env, uid) {
  if (!uidValid(uid)) throw new ServiceError('unauthorized', 401);
  const result = await jsonFetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`, {
    method: 'POST', headers: {Authorization: `Bearer ${await googleToken(env)}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({localId: [uid]})});
  return result.users?.find(u => u.localId === uid) || null;
}
export async function verifyToken(env, token) {
  if (typeof token !== 'string' || token.length > 8192) throw new ServiceError('unauthorized', 401);
  try {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error();
    const header = JSON.parse(new TextDecoder().decode(bytes(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(bytes(parts[1])));
    const now = Date.now() / 1000;
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' || claims.aud !== PROJECT
      || claims.iss !== `https://securetoken.google.com/${PROJECT}` || !uidValid(claims.sub)
      || !Number.isFinite(claims.exp) || claims.exp <= now || !Number.isFinite(claims.iat)
      || claims.iat > now + 30 || !Number.isFinite(claims.auth_time) || claims.auth_time > now + 30) throw new Error();
    if (!jwks || jwks.until < now || !jwks.keys.some(k => k.kid === header.kid)) {
      const result = await jsonFetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
      if (!Array.isArray(result.keys)) throw new Error();
      jwks = {keys: result.keys, until: now + 300};
    }
    const jwk = jwks.keys.find(k => k.kid === header.kid && k.kty === 'RSA');
    if (!jwk) throw new Error();
    const key = await crypto.subtle.importKey('jwk', jwk, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['verify']);
    if (!await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, bytes(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`))) throw new Error();
    const user = await lookupUser(env, claims.sub);
    const validSince = Number(user?.validSince || 0);
    if (!user || user.disabled || !Number.isFinite(validSince) || validSince > claims.auth_time) throw new Error();
    return {uid: claims.sub, user};
  } catch (error) {
    if (error instanceof ServiceError) throw error;
    throw new ServiceError('unauthorized', 401);
  }
}
export function field(value) {
  if (value === null) return {nullValue: null};
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (Number.isSafeInteger(value)) return {integerValue: String(value)};
  if (typeof value === 'string') return {stringValue: value};
  throw new ServiceError();
}
function unfield(value) {
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('integerValue' in value) return Number(value.integerValue);
  return value.booleanValue ?? value.stringValue ?? null;
}
export class Store {
  constructor(env) { this.env = env; this.prefix = `projects/${PROJECT}/databases/(default)/documents/`; this.url = `https://firestore.googleapis.com/v1/${this.prefix.slice(0, -1)}`; }
  async api(suffix, body, method = 'POST', missing = false) {
    const response = await fetch(this.url + suffix, {method, redirect: 'error', signal: AbortSignal.timeout(8000),
      headers: {Authorization: `Bearer ${await googleToken(this.env)}`, 'Content-Type': 'application/json'},
      ...(body === undefined ? {} : {body: JSON.stringify(body)})});
    if (missing && response.status === 404) return null;
    if (!response.ok) throw new ServiceError('service_unavailable', 503, await providerFailure(response));
    return JSON.parse(await limitedText(response, 256 * 1024));
  }
  decode(doc) { return doc ? {path: doc.name.slice(this.prefix.length), updateTime: doc.updateTime,
    data: Object.fromEntries(Object.entries(doc.fields || {}).map(([key, value]) => [key, unfield(value)]))} : null; }
  async get(path, tx) { return this.decode(await this.api(`/${path}${tx ? '?transaction=' + encodeURIComponent(tx) : ''}`, undefined, 'GET', true)); }
  set(path, data, merge = true) { return {update: {name: this.prefix + path,
    fields: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, field(value)]))},
    ...(merge ? {updateMask: {fieldPaths: Object.keys(data)}} : {})}; }
  remove(path) { return {delete: this.prefix + path}; }
  async commit(writes, transaction) { return this.api(':commit', {writes, ...(transaction ? {transaction} : {})}); }
  async transaction(action) {
    const {transaction} = await this.api(':beginTransaction', {options: {readWrite: {}}});
    if (typeof transaction !== 'string' || !transaction.length) throw new ServiceError();
    try { return await action(transaction); }
    finally { try { await this.api(':rollback', {transaction}); } catch { /* Successful commits already close the transaction. */ } }
  }
  async query(collection, filters = [], order = 'createdAt', limit = 1) {
    const clauses = filters.map(([name, op, value]) => ({fieldFilter: {field: {fieldPath: name}, op, value: field(value)}}));
    const result = await this.api(':runQuery', {structuredQuery: {from: [{collectionId: collection}],
      ...(clauses.length ? {where: clauses.length === 1 ? clauses[0] : {compositeFilter: {op: 'AND', filters: clauses}}} : {}),
      orderBy: [{field: {fieldPath: order}, direction: 'ASCENDING'}], limit}});
    if (!Array.isArray(result)) throw new ServiceError();
    return result.filter(row => row.document).map(row => this.decode(row.document));
  }
}
