import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyToken, account} from '../src/google.mjs';

test('real RSA verification rejects forged, expired, foreign-project, disabled and revoked Firebase tokens', async () => {
  const pair = await crypto.subtle.generateKey({name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'}, true, ['sign', 'verify']);
  const jwk = await crypto.subtle.exportKey('jwk', pair.publicKey); jwk.kid = 'test-watchloom-key';
  const secret = Buffer.from(await crypto.subtle.exportKey('pkcs8', pair.privateKey)).toString('base64');
  const env = {FIREBASE_PROJECT_ID: 'watchloom-canturhan', FIREBASE_SERVICE_ACCOUNT: JSON.stringify({
    project_id: 'watchloom-canturhan', client_email: 'watchloom-community@watchloom-canturhan.iam.gserviceaccount.com',
    token_uri: 'https://oauth2.googleapis.com/token', private_key: `-----BEGIN PRIVATE KEY-----\n${secret}\n-----END PRIVATE KEY-----`})};
  const now = Math.floor(Date.now() / 1000), original = globalThis.fetch;
  let user = {localId: 'verified-author', emailVerified: true, validSince: String(now - 3600)}, lookups = 0;
  globalThis.fetch = async (url) => {
    if (String(url).includes('/service_accounts/v1/jwk/')) return Response.json({keys: [jwk]});
    if (url === 'https://oauth2.googleapis.com/token') return Response.json({access_token: 'local-only-test-token', expires_in: 3600});
    if (String(url).startsWith('https://identitytoolkit.googleapis.com/v1/projects/watchloom-canturhan/accounts:lookup')) {
      lookups++; return Response.json({users: user ? [user] : []});
    }
    throw new Error('Unexpected network request: test forbids external services');
  };
  const b64 = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  async function token(patch = {}, header = {}) {
    const text = b64({alg: 'RS256', kid: jwk.kid, ...header}) + '.' + b64({
      sub: 'verified-author', iss: 'https://securetoken.google.com/watchloom-canturhan', aud: 'watchloom-canturhan',
      iat: now, auth_time: now - 100, exp: now + 3600, ...patch});
    return text + '.' + Buffer.from(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey,
      new TextEncoder().encode(text))).toString('base64url');
  }
  try {
    assert.equal((await verifyToken(env, await token())).uid, 'verified-author');
    for (const patch of [{aud: 'other-project'}, {iss: 'https://evil.test'}, {sub: '../path'}, {exp: now - 1},
      {iat: now + 3600}, {auth_time: now + 3600}, {exp: 'future'}]) {
      const before = lookups;
      await assert.rejects(verifyToken(env, await token(patch)), {code: 'unauthorized'});
      assert.equal(lookups, before);
    }
    await assert.rejects(verifyToken(env, await token({}, {alg: 'none'})), {code: 'unauthorized'});
    const valid = await token(); const parts = valid.split('.'); parts[1] = b64({sub: 'attacker', aud: 'watchloom-canturhan',
      iss: 'https://securetoken.google.com/watchloom-canturhan', exp: now + 3600, iat: now, auth_time: now});
    await assert.rejects(verifyToken(env, parts.join('.')), {code: 'unauthorized'});
    user = {...user, disabled: true}; await assert.rejects(verifyToken(env, valid), {code: 'unauthorized'});
    user = {...user, disabled: false, validSince: String(now)}; await assert.rejects(verifyToken(env, valid), {code: 'unauthorized'});
    user = {...user, validSince: 'invalid-revocation-time'}; await assert.rejects(verifyToken(env, valid), {code: 'unauthorized'});
    user = null; await assert.rejects(verifyToken(env, valid), {code: 'unauthorized'});
    assert.throws(() => account({...env, FIREBASE_PROJECT_ID: 'puzzle-music-sort-canturhan'}));
  } finally { globalThis.fetch = original; }
});
