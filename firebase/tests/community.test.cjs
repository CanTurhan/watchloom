'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomBytes, randomUUID} = require('node:crypto');

test('Spark automatic series community and vote security rules', {timeout: 180000}, async t => {
  for (const host of [process.env.FIRESTORE_EMULATOR_HOST, process.env.FIREBASE_AUTH_EMULATOR_HOST]) {
    assert.ok(host && ['127.0.0.1', 'localhost', '[::1]'].includes(new URL(`http://${host}`).hostname),
      'Local Auth + Firestore emulators are mandatory; production is forbidden.');
  }
  const project = 'demo-watchloom';
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const {getFirestore, Timestamp} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: project}, 'watchloom-community-rules-tests');
  const auth = getAuth(app), db = getFirestore(app);
  const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents`;
  const authBase = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;
  const prefix = `projects/${project}/databases/(default)/documents/`;
  const id = () => randomBytes(10).toString('hex');
  async function request(url, {token, data, method = 'POST'} = {}) {
    const res = await fetch(url, {method, headers: {'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(45000)});
    return {status: res.status, json: await res.json()};
  }
  function value(v) {
    if (v === null) return {nullValue: null};
    if (v instanceof Date) return {timestampValue: v.toISOString()};
    if (typeof v === 'boolean') return {booleanValue: v};
    if (Number.isInteger(v)) return {integerValue: `${v}`};
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
  async function user(verified = true) {
    const email = `community-${randomUUID()}@example.test`, password = 'Emulator-only-password-47!';
    const created = await request(`${authBase}/accounts:signUp?key=local`, {data: {email, password, returnSecureToken: true}});
    assert.equal(created.status, 200);
    if (!verified) return {uid: created.json.localId, token: created.json.idToken};
    await auth.updateUser(created.json.localId, {emailVerified: true});
    const signed = await request(`${authBase}/accounts:signInWithPassword?key=local`, {data: {email, password, returnSecureToken: true}});
    assert.equal(signed.status, 200);
    const identity = {uid: signed.json.localId, token: signed.json.idToken};
    assert.equal((await write(`users/${identity.uid}`, {schema: 1, status: 'active', revision: 0,
      activeBackupId: null, previousBackupId: null}, identity.token, {timestamps: ['createdAt', 'updatedAt']})).status, 200);
    return identity;
  }
  function profileWrites(identity, handle, extra = {}) {
    return [update(`communityProfiles/${identity.uid}`, {schema: 1, handle, nickname: null, displayMode: 'handle',
      lastPostAt: new Date(0), lastPostId: null, postWindowAt: new Date(0), postsInWindow: 0,
      lastReportAt: new Date(0), lastReportId: null, reportWindowAt: new Date(0), reportsInWindow: 0,
      voteCount: 0, lastVoteAt: new Date(0), lastVoteId: null,
      acceptedPolicyVersion: '2026-11-06-auto-v1', ...extra}, {timestamps: ['createdAt', 'updatedAt', 'acceptedPolicyAt']}),
    update(`communityHandles/${handle}`, {uid: identity.uid}, {timestamps: ['createdAt']})];
  }
  async function counterWrite(identity, kind, identifier) {
    const profile = (await db.doc(`communityProfiles/${identity.uid}`).get()).data();
    const stem = kind === 'Post' ? 'post' : 'report', window = `${stem}WindowAt`, count = `${stem}sInWindow`;
    const reset = Date.now() - profile[window].toMillis() >= 86400000;
    return update(`communityProfiles/${identity.uid}`, {['last' + kind + 'Id']: identifier,
      [count]: reset ? 1 : profile[count] + 1, ...(!reset ? {[window]: profile[window].toDate()} : {})},
    {patch: true, timestamps: ['last' + kind + 'At', ...(reset ? [window] : [])]});
  }
  async function postWrites(identity, identifier, extra = {}) {
    return [update(`communityComments/${identifier}`, {schema: 1, contentKey: 'tvmaze:show:123', contentKind: 'series',
      authorUid: identity.uid, authorName: `@fan_${identity.uid.slice(0, 8).toLowerCase()}`, body: 'Final harikaydı 🎬',
      parentId: null, isSpoiler: false, status: 'pending', policyVersion: '2026-11-06-auto-v1',
      scoreSchema: 1, upVotes: 0, downVotes: 0, score: 0,
      ...extra}, {timestamps: ['createdAt', 'moderationNextAt']}),
    await counterWrite(identity, 'Post', identifier)];
  }
  const post = async (identity, identifier, extra) => commit(await postWrites(identity, identifier, extra), identity.token);
  async function reportWrites(identity, reportId, commentId, extra = {}) {
    return [update(`communityReports/${reportId}`, {commentId, reporterUid: identity.uid, reason: 'abuse', ...extra},
      {timestamps: ['createdAt']}),
    update(`users/${identity.uid}/communityReportRefs/${reportId}`, {reportId}, {timestamps: ['createdAt']}),
    await counterWrite(identity, 'Report', reportId)];
  }
  async function resetPost(identity) {
    await db.doc(`communityProfiles/${identity.uid}`).update({lastPostAt: Timestamp.fromMillis(0)});
  }
  async function voteWrites(identity, commentId, next) {
    const votePath = `users/${identity.uid}/communityVotes/${commentId}`;
    const [comment, prior, profile] = await Promise.all([db.doc(`communityComments/${commentId}`).get(),
      db.doc(votePath).get(), db.doc(`communityProfiles/${identity.uid}`).get()]);
    const old = prior.exists ? prior.data().value : 0, writes = [];
    if (comment.exists) {
      const before = comment.data(), up = (before.upVotes || 0) + Number(next === 1) - Number(old === 1),
        down = (before.downVotes || 0) + Number(next === -1) - Number(old === -1);
      writes.push(update(`communityComments/${commentId}`, {scoreSchema: 1, upVotes: up, downVotes: down, score: up - down}, {patch: true}));
    }
    writes.push(next === 0 ? {delete: prefix + votePath} : update(votePath, {commentId, value: next}, {timestamps: ['updatedAt']}));
    writes.push(update(`communityProfiles/${identity.uid}`, {voteCount: (profile.data().voteCount || 0)
      + Number(next !== 0) - Number(old !== 0), lastVoteId: commentId}, {patch: true, timestamps: ['lastVoteAt']}));
    return writes;
  }
  const resetVote = identity => db.doc(`communityProfiles/${identity.uid}`).update({lastVoteAt: Timestamp.fromMillis(0)});
  try {
    const a = await user(), b = await user(), mod = await user(), unverified = await user(false);
    const handles = new Map([a, b, mod].map(x => [x.uid, `fan_${x.uid.slice(0, 8).toLowerCase()}`]));
    await db.doc('communityConfig/current').set({enabled: true, moderationReady: true,
      rulesVersion: 2, moderationMode: 'automatic'});
    await db.doc(`communityModerators/${mod.uid}`).set({active: true});
    const rootId = id(), replyId = id(), reportId = id();
    await t.test('verified explicit identity and policy consent; no forged roles or private profile reads', async () => {
      assert.equal((await commit(profileWrites(unverified, 'unverified_user'), unverified.token)).status, 403);
      assert.equal((await commit(profileWrites(a, handles.get(a.uid), {acceptedPolicyVersion: 'old'}), a.token)).status, 403);
      for (const identity of [a, b, mod]) assert.equal((await commit(profileWrites(identity, handles.get(identity.uid)), identity.token)).status, 200);
      assert.equal((await read(`communityProfiles/${a.uid}`, b.token)).status, 403);
      assert.equal((await read(`communityHandles/${handles.get(a.uid)}`, b.token)).status, 403);
      assert.equal((await write(`communityModerators/${b.uid}`, {active: true}, b.token)).status, 403);
      assert.equal((await write('communityConfig/current', {enabled: true}, b.token)).status, 403);
      assert.equal((await write(`communityProfiles/${a.uid}`, {premium: true}, a.token, {patch: true})).status, 403);
    });
    await t.test('posts fail closed until operational config is ready; publication is never client-controlled', async () => {
      await db.doc('communityConfig/current').update({moderationReady: false});
      assert.equal((await post(a, rootId)).status, 403);
      await db.doc('communityConfig/current').update({moderationReady: true});
      assert.equal((await post(a, rootId, {status: 'approved'})).status, 403);
      assert.equal((await post(a, rootId, {authorName: 'attacker@example.com'})).status, 403);
      assert.equal((await post(a, rootId, {contentKey: 'local:uuid'})).status, 403);
      assert.equal((await post(a, rootId, {contentKind: 'movie'})).status, 403);
      assert.equal((await post(a, rootId)).status, 200);
      assert.equal((await read(`communityComments/${rootId}`)).status, 403);
      assert.equal((await read(`communityComments/${rootId}`, b.token)).status, 403);
      assert.equal((await read(`communityComments/${rootId}`, a.token)).status, 200);
      assert.equal((await read(`communityComments/${rootId}`, mod.token)).status, 200);
      assert.equal((await write(`communityComments/${rootId}`, {status: 'approved'}, a.token, {patch: true})).status, 403);
      assert.equal((await write(`communityComments/${rootId}`, {status: 'approved'}, mod.token, {patch: true})).status, 403);
      await db.doc(`communityComments/${rootId}`).update({status: 'approved'});
      assert.equal((await read(`communityComments/${rootId}`)).status, 200);
    });
    await t.test('public and owner-only block queries require explicit bounded limits', async () => {
      const query = (where, limit = 50, token) => request(`${base}:runQuery`, {token,
        data: {structuredQuery: {from: [{collectionId: 'communityComments'}], ...(where ? {where} : {}), limit}}});
      assert.equal((await query()).status, 403);
      const approved = {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: value('approved')}};
      assert.equal((await query(approved)).status, 200);
      assert.equal((await query(approved, 1000)).status, 403);
      assert.equal((await request(`${base}:runQuery`, {data: {structuredQuery: {
        from: [{collectionId: 'communityComments'}], where: approved}}})).status, 403);
      // REST ListDocuments is a paginated endpoint: its server-selected page
      // limit is not an unbounded Firestore query. Exercise runQuery directly,
      // as the app's SDK does, with seeded private data and explicit limits.
      assert.equal((await write(`communityBlocks/${a.uid}/authors/${b.uid}`,
        {blockedUid: b.uid}, a.token, {timestamps: ['createdAt']})).status, 200);
      const blocks = (token, limit) => request(`${base}/communityBlocks/${a.uid}:runQuery`, {token,
        data: {structuredQuery: {from: [{collectionId: 'authors'}], ...(limit === undefined ? {} : {limit})}}});
      const ownPage = await blocks(a.token, 100);
      assert.equal(ownPage.status, 200);
      assert.ok(ownPage.json.some(row => row.document?.name.endsWith(`/authors/${b.uid}`)));
      assert.equal((await blocks(a.token)).status, 403);
      assert.equal((await blocks(a.token, 101)).status, 403);
      assert.equal((await blocks(b.token, 100)).status, 403);
      assert.equal((await blocks(undefined, 100)).status, 403);
      assert.equal((await remove(`communityBlocks/${a.uid}/authors/${b.uid}`, a.token)).status, 200);
    });
    await t.test('atomic counters enforce cooldown, daily cap and no reset; unsafe raw REST text is denied', async () => {
      assert.equal((await post(a, id())).status, 403);
      await resetPost(a);
      for (const body of ['fuck you', 'safe\u200Bhidden', 'safe\u202Ehidden', 'mail@example.com', 'https://evil.test']) {
        assert.equal((await post(a, id(), {body})).status, 403, body);
      }
      assert.equal((await post(a, id(), {body: 'Shiitake soup scene'})).status, 200);
      assert.equal((await write(`communityProfiles/${a.uid}`, {lastPostAt: new Date(0)}, a.token, {patch: true})).status, 403);
      await db.doc(`communityProfiles/${a.uid}`).update({lastPostAt: Timestamp.fromMillis(0), postsInWindow: 20});
      assert.equal((await post(a, id())).status, 403);
      await db.doc(`communityProfiles/${a.uid}`).update({postsInWindow: 2});
    });
    await t.test('replies need an approved root from same series; mutual blocks stop contact', async () => {
      assert.equal((await post(b, id(), {parentId: rootId, contentKey: 'tvmaze:show:999'})).status, 403);
      assert.equal((await post(b, replyId, {parentId: rootId, isSpoiler: true})).status, 200);
      await db.doc(`communityComments/${replyId}`).update({status: 'approved'});
      await resetPost(b);
      assert.equal((await post(b, id(), {parentId: replyId})).status, 403);
      assert.equal((await write(`communityBlocks/${a.uid}/authors/${b.uid}`, {blockedUid: b.uid}, a.token,
        {timestamps: ['createdAt']})).status, 200);
      assert.equal((await read(`communityBlocks/${a.uid}/authors/${b.uid}`, b.token)).status, 403);
      assert.equal((await post(b, id(), {parentId: rootId})).status, 403);
      // Public web-like reads cannot be a confidentiality barrier. The app
      // filters blocked authors; rules enforce no direct replies either way.
      assert.equal((await read(`communityComments/${rootId}`, b.token)).status, 200);
      assert.equal((await remove(`communityBlocks/${a.uid}/authors/${b.uid}`, a.token)).status, 200);
    });
    await t.test('reports remain private, minimal and usable while publishing is disabled', async () => {
      await db.doc('communityConfig/current').update({enabled: false});
      assert.equal((await commit(await reportWrites(a, reportId, replyId, {body: 'copied private text'}), a.token)).status, 403);
      assert.equal((await commit(await reportWrites(a, reportId, replyId), a.token)).status, 200);
      assert.equal((await read(`communityReports/${reportId}`, a.token)).status, 403);
      assert.equal((await read(`communityReports/${reportId}`, b.token)).status, 403);
      assert.equal((await read(`communityReports/${reportId}`, mod.token)).status, 200);
      assert.equal((await remove(`communityReports/${reportId}`, a.token)).status, 403);
      assert.equal((await commit(await reportWrites(a, id(), replyId), a.token)).status, 403);
      assert.equal((await read(`users/${a.uid}/communityReportRefs/${reportId}`, b.token)).status, 403);
      await db.doc('communityConfig/current').update({enabled: true});
    });
    await t.test('votes require exact atomic counters and a private single vote; self-votes and status forgery fail', async () => {
      assert.equal((await commit(await voteWrites(a, rootId, 1), a.token)).status, 403);
      const good = await voteWrites(b, rootId, 1);
      assert.equal((await commit(good.slice(0, 2), b.token)).status, 403);
      assert.equal((await commit(good.slice(1), b.token)).status, 403);
      const forged = structuredClone(good); forged[0].update.fields.score = value(1000);
      assert.equal((await commit(forged, b.token)).status, 403);
      assert.equal((await db.doc(`communityComments/${rootId}`).get()).data().status, 'approved');
      // Writing approved again is a no-op, so MapDiff correctly ignores it.
      // Exercise an actual forbidden status change on the approved target.
      const changedStatus = structuredClone(good);
      changedStatus[0].update.fields.status = value('pending');
      changedStatus[0].updateMask.fieldPaths.push('status');
      assert.equal((await commit(changedStatus, b.token)).status, 403);
      assert.equal((await commit(good, b.token)).status, 200);
      assert.equal((await db.doc(`communityComments/${rootId}`).get()).data().score, 1);
      assert.equal((await db.doc(`communityProfiles/${b.uid}`).get()).data().voteCount, 1);
      assert.equal((await read(`users/${b.uid}/communityVotes/${rootId}`, a.token)).status, 403);
      assert.equal((await read(`users/${b.uid}/communityVotes/${rootId}`, b.token)).status, 200);
      assert.equal((await commit(await voteWrites(b, rootId, 1), b.token)).status, 403);
      await resetVote(b);
      assert.equal((await commit(await voteWrites(b, rootId, -1), b.token)).status, 200);
      assert.equal((await db.doc(`communityComments/${rootId}`).get()).data().score, -1);
      assert.equal((await db.doc(`communityProfiles/${b.uid}`).get()).data().voteCount, 1);
      await resetVote(b);
      assert.equal((await commit(await voteWrites(b, rootId, 0), b.token)).status, 200);
      assert.equal((await db.doc(`communityComments/${rootId}`).get()).data().score, 0);
      await resetVote(b);
      assert.equal((await commit(await voteWrites(b, rootId, 1), b.token)).status, 200);
      await db.doc(`communityComments/${rootId}`).update({status: 'rejected'});
      assert.equal((await read(`communityComments/${rootId}`, b.token)).status, 403);
      await resetVote(b);
      // Counter withdrawal is permitted without granting access to rejected text.
      const hiddenWithdrawal = await voteWrites(b, rootId, 0);
      assert.equal((await commit(hiddenWithdrawal.slice(1), b.token)).status, 403);
      hiddenWithdrawal[0].update.fields = {scoreSchema: value(1)};
      hiddenWithdrawal[0].updateMask.fieldPaths = ['scoreSchema'];
      hiddenWithdrawal[0].updateTransforms = [
        {fieldPath: 'upVotes', increment: value(-1)},
        {fieldPath: 'downVotes', increment: value(0)},
        {fieldPath: 'score', increment: value(-1)},
      ];
      assert.equal((await commit(hiddenWithdrawal, b.token)).status, 200);
      await db.doc(`communityComments/${rootId}`).update({status: 'approved'});
    });
    await t.test('blocking prevents new votes while withdrawal remains possible, and missing targets can be cleaned', async () => {
      await resetVote(b);
      assert.equal((await commit(await voteWrites(b, rootId, 1), b.token)).status, 200);
      await db.doc(`communityBlocks/${a.uid}/authors/${b.uid}`).set({blockedUid: b.uid, createdAt: Timestamp.now()});
      await resetVote(b);
      assert.equal((await commit(await voteWrites(b, rootId, -1), b.token)).status, 403);
      assert.equal((await commit(await voteWrites(b, rootId, 0), b.token)).status, 200);
      await db.doc(`communityBlocks/${a.uid}/authors/${b.uid}`).delete();
      const missing = id();
      await db.doc(`users/${b.uid}/communityVotes/${missing}`).set({commentId: missing, value: 1, updatedAt: Timestamp.now()});
      await db.doc(`communityProfiles/${b.uid}`).update({voteCount: 1, lastVoteAt: Timestamp.fromMillis(0)});
      assert.equal((await read(`communityComments/${missing}`, b.token)).status, 404);
      const missingWithdrawal = await voteWrites(b, missing, 0);
      const blindMissing = update(`communityComments/${missing}`, {scoreSchema: 1}, {patch: true});
      blindMissing.currentDocument = {exists: true};
      blindMissing.updateTransforms = [{fieldPath: 'upVotes', increment: value(-1)},
        {fieldPath: 'downVotes', increment: value(0)}, {fieldPath: 'score', increment: value(-1)}];
      assert.ok([403, 404].includes((await commit([blindMissing, ...missingWithdrawal], b.token)).status));
      assert.equal((await commit(await voteWrites(b, missing, 0), b.token)).status, 200);
      assert.equal((await db.doc(`communityProfiles/${b.uid}`).get()).data().voteCount, 0);
    });
    await t.test('deletion lock prevents stale writes and cleans owned UGC without erasing others replies', async () => {
      await resetVote(a);
      assert.equal((await commit(await voteWrites(a, replyId, 1), a.token)).status, 200);
      assert.equal((await write(`communityBlocks/${a.uid}/authors/${b.uid}`, {blockedUid: b.uid}, a.token,
        {timestamps: ['createdAt']})).status, 200);
      assert.equal((await commit([update(`deletionMarkers/${a.uid}`, {nonce: randomBytes(32).toString('base64')},
        {timestamps: ['startedAt']}), update(`users/${a.uid}`, {status: 'deleting'},
        {patch: true, timestamps: ['deletionRequestedAt']})], a.token)).status, 200);
      assert.equal((await post(a, id())).status, 403);
      assert.equal((await commit([{delete: prefix + `communityProfiles/${a.uid}`},
        {delete: prefix + `communityHandles/${handles.get(a.uid)}`}], a.token)).status, 403);
      assert.equal((await commit(await voteWrites(a, replyId, 0), a.token)).status, 200);
      // v6 knows only backups/root/Auth. It must fail closed until the updated
      // app removes UGC; otherwise Auth deletion would strand public content.
      assert.equal((await commit([update(`deletionMarkers/${a.uid}`, {},
        {patch: true, timestamps: ['purgedAt']}), {delete: prefix + `users/${a.uid}`}], a.token)).status, 403);
      assert.equal((await db.doc(`users/${a.uid}`).get()).exists, true);
      const owned = await db.collection('communityComments').where('authorUid', '==', a.uid).get();
      for (const doc of owned.docs) assert.equal((await remove(`communityComments/${doc.id}`, a.token)).status, 200);
      assert.equal((await commit([{delete: prefix + `communityReports/${reportId}`},
        {delete: prefix + `users/${a.uid}/communityReportRefs/${reportId}`}], a.token)).status, 200);
      assert.equal((await remove(`communityBlocks/${a.uid}/authors/${b.uid}`, a.token)).status, 200);
      assert.equal((await commit([{delete: prefix + `communityProfiles/${a.uid}`},
        {delete: prefix + `communityHandles/${handles.get(a.uid)}`}], a.token)).status, 200);
      assert.equal((await db.collection('communityComments').where('authorUid', '==', a.uid).get()).size, 0);
      assert.equal((await read(`communityComments/${replyId}`)).status, 200);
      assert.equal((await commit(profileWrites(a, handles.get(a.uid)), a.token)).status, 403);
      assert.equal((await commit([update(`deletionMarkers/${a.uid}`, {},
        {patch: true, timestamps: ['purgedAt']}), {delete: prefix + `users/${a.uid}`}], a.token)).status, 200);
    });
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
});
