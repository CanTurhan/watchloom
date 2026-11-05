'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomUUID, randomBytes} = require('node:crypto');
const project = 'demo-watchloom';

test('Spark account, backup and deletion security rules', {timeout: 180000}, async t => {
  for (const host of [process.env.FIRESTORE_EMULATOR_HOST, process.env.FIREBASE_AUTH_EMULATOR_HOST]) {
    assert.ok(host && ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(`http://${host}`).hostname),
      'Run using bash scripts/deploy_firebase.sh --check; production targets are forbidden.');
  }
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const {getFirestore, Timestamp} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: project}, 'watchloom-local-rules-tests');
  const adminAuth = getAuth(app), adminDb = getFirestore(app);
  const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents`;
  const authBase = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;
  const prefix = `projects/${project}/databases/(default)/documents/`;
  async function request(url, {token, data, method = 'POST'} = {}) {
    const res = await fetch(url, {method, headers: {'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {})},
      body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(45000)});
    return {status: res.status, json: await res.json()};
  }
  async function user(verified = true) {
    const email = `watchloom-${randomUUID()}@example.test`, password = 'Emulator-only-password-47!';
    const created = await request(`${authBase}/accounts:signUp?key=local-test-key`,
      {data: {email, password, returnSecureToken: true}});
    assert.equal(created.status, 200);
    if (!verified) return {uid: created.json.localId, token: created.json.idToken};
    await adminAuth.updateUser(created.json.localId, {emailVerified: true});
    const signed = await request(`${authBase}/accounts:signInWithPassword?key=local-test-key`,
      {data: {email, password, returnSecureToken: true}});
    assert.equal(signed.status, 200);
    return {uid: signed.json.localId, token: signed.json.idToken};
  }
  function value(v) {
    if (v === null) return {nullValue: null};
    if (typeof v === 'boolean') return {booleanValue: v};
    if (Number.isInteger(v)) return {integerValue: `${v}`};
    if (Buffer.isBuffer(v)) return {bytesValue: v.toString('base64')};
    return {stringValue: v};
  }
  function update(path, data, {patch = false, timestamps = []} = {}) {
    return {update: {name: prefix + path,
      fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]))},
    ...(patch ? {updateMask: {fieldPaths: Object.keys(data)}} : {}),
    ...(timestamps.length ? {updateTransforms: timestamps.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {})};
  }
  const commit = (writes, token) => request(`${base}:commit`, {token, data: {writes}});
  const write = (path, data, token, options) => commit([update(path, data, options)], token);
  const read = (path, token) => request(`${base}/${path}`, {token, method: 'GET'});
  const remove = (path, token) => request(`${base}/${path}`, {token, method: 'DELETE'});
  function bootstrap(identity) {
    return write(`users/${identity.uid}`, {schema: 1, status: 'active', revision: 0,
      activeBackupId: null, previousBackupId: null}, identity.token, {timestamps: ['createdAt', 'updatedAt']});
  }
  try {
    const a = await user(), b = await user(), unverified = await user(false);
    const root = `users/${a.uid}`, marker = `deletionMarkers/${a.uid}`;
    const backupId = randomUUID(), backup = `${root}/backups/${backupId}`;
    const nonce = randomBytes(32).toString('base64');
    await t.test('anonymous, unverified and forged owner documents are rejected', async () => {
      assert.equal((await read('users')).status, 403);
      assert.equal((await bootstrap(unverified)).status, 403);
      assert.equal((await write(root, {status: 'active', premium: true}, a.token)).status, 403);
      assert.equal((await bootstrap(a)).status, 200);
      assert.equal((await bootstrap(b)).status, 200);
      assert.equal((await read(root, a.token)).status, 200);
      assert.equal((await read(root, b.token)).status, 403);
      assert.equal((await write(root, {premium: true}, a.token, {patch: true})).status, 403);
      assert.equal((await read(marker, b.token)).status, 403);
    });
    await t.test('immutable snapshots and revision checks prevent silent replacement', async () => {
      assert.equal((await write(backup, {schema: 1, complete: false, chunks: 1, bytes: 3, sha256: 'a'.repeat(64)},
        a.token, {timestamps: ['createdAt']})).status, 200);
      const pointer = {revision: 1, activeBackupId: backupId, previousBackupId: null};
      assert.equal((await write(root, pointer, a.token, {patch: true, timestamps: ['updatedAt']})).status, 403);
      assert.equal((await write(`${backup}/chunks/0`, {payload: Buffer.from('abc')}, b.token)).status, 403);
      assert.equal((await write(`${backup}/chunks/0`, {payload: Buffer.from('abc')}, a.token)).status, 200);
      assert.equal((await write(`${backup}/chunks/0`, {payload: Buffer.from('other')}, a.token)).status, 403);
      assert.equal((await write(backup, {complete: true}, a.token, {patch: true})).status, 200);
      assert.equal((await write(`${backup}/chunks/1`, {payload: Buffer.from('abc')}, a.token)).status, 403);
      assert.equal((await write(root, pointer, a.token, {patch: true, timestamps: ['updatedAt']})).status, 200);
      assert.equal((await write(root, {...pointer, revision: 3}, a.token, {patch: true, timestamps: ['updatedAt']})).status, 403);
      assert.equal((await remove(backup, a.token)).status, 403);
    });
    await t.test('client pruning cannot delete protected or recent backups', async () => {
      const old = `${root}/backups/${randomUUID()}`, recent = `${root}/backups/${randomUUID()}`;
      await adminDb.doc(old).set({createdAt: Timestamp.fromMillis(1)});
      await adminDb.doc(`${old}/chunks/0`).set({payload: Buffer.from('old')});
      await adminDb.doc(recent).set({createdAt: Timestamp.now()});
      assert.equal((await remove(`${backup}/chunks/0`, a.token)).status, 403);
      assert.equal((await remove(recent, a.token)).status, 403);
      assert.equal((await remove(`${old}/chunks/0`, a.token)).status, 200);
      assert.equal((await remove(old, a.token)).status, 200);
    });
    await t.test('a deletion lock requires fresh authentication and is atomic', async () => {
      const claims = JSON.parse(Buffer.from(a.token.split('.')[1], 'base64url'));
      const stale = `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.${Buffer.from(JSON.stringify({...claims, auth_time: Math.floor(Date.now() / 1000) - 600})).toString('base64url')}.`;
      const lock = [update(marker, {nonce}, {timestamps: ['startedAt']}),
        update(root, {status: 'deleting'}, {patch: true, timestamps: ['deletionRequestedAt']})];
      assert.equal((await commit(lock, stale)).status, 403);
      assert.equal((await write(root, {status: 'deleting'}, a.token, {patch: true, timestamps: ['deletionRequestedAt']})).status, 403);
      assert.equal((await commit(lock, a.token)).status, 200);
      assert.equal((await read(`${backup}/chunks/0`, a.token)).status, 200);
      assert.equal((await read(`${backup}/chunks/0`, b.token)).status, 403);
      assert.equal((await write(`${backup}/chunks/1`, {payload: Buffer.from('x')}, a.token)).status, 403);
      assert.equal((await remove(root, a.token)).status, 403);
      assert.equal((await remove(marker, a.token)).status, 403);
    });
    await t.test('erase content before Auth; a stale token cannot recreate the account', async () => {
      // Exercise the same paged, chunk-before-manifest ordering as the app.
      while (true) {
        const snapshots = (await read(`${root}/backups?pageSize=20`, a.token)).json.documents || [];
        if (!snapshots.length) break;
        for (const snapshot of snapshots) {
          const location = snapshot.name.slice(prefix.length);
          while (true) {
            const children = (await read(`${location}/chunks?pageSize=20`, a.token)).json.documents || [];
            if (!children.length) break;
            for (const child of children) assert.equal((await remove(child.name.slice(prefix.length), a.token)).status, 200);
          }
          assert.equal((await remove(location, a.token)).status, 200);
        }
      }
      assert.equal((await commit([update(marker, {nonce}, {patch: true, timestamps: ['purgedAt']}), {delete: prefix + root}], a.token)).status, 200);
      assert.equal((await request(`${authBase}/accounts:delete?key=local-test-key`, {data: {idToken: a.token}})).status, 200);
      await assert.rejects(adminAuth.getUser(a.uid), {code: 'auth/user-not-found'});
      assert.equal((await bootstrap(a)).status, 403);
      assert.equal((await adminDb.collection(`${root}/backups`).get()).size, 0);
      assert.equal((await adminAuth.getUser(b.uid)).uid, b.uid);
    });
    await t.test('only the private proof can complete an erased marker; early/public deletion is forbidden', async () => {
      assert.equal((await read(marker)).status, 403);
      assert.equal((await read('deletionMarkers')).status, 403);
      assert.equal((await write(marker, {completionProof: 'guessed'}, undefined, {patch: true, timestamps: ['authDeletedAt']})).status, 403);
      assert.equal((await write(marker, {completionProof: nonce}, undefined, {patch: true, timestamps: ['authDeletedAt']})).status, 200);
      assert.equal((await remove(marker)).status, 403);
      // Advance only this local fixture's guard timestamp. In production all
      // ID tokens issued before Auth deletion expire before this two-hour gap.
      await adminDb.doc(marker).update({authDeletedAt: Timestamp.fromMillis(Date.now() - 3 * 3600000)});
      assert.equal((await remove(marker)).status, 200);
    });
    await t.test('unverified accounts can erase themselves without creating a backup profile', async () => {
      const m = `deletionMarkers/${unverified.uid}`;
      assert.equal((await write(m, {nonce: randomBytes(32).toString('base64')}, unverified.token, {timestamps: ['startedAt']})).status, 200);
      assert.equal((await read(`users/${unverified.uid}/backups`, unverified.token)).status, 200);
    });
  } finally {
    await adminDb.terminate();
    await deleteApp(app);
  }
});
