'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {run, validUid, validEmail, validId, verifiedAccount, safeToApprove, privateOptions, update} = require('./community_moderation.cjs');
const PREFIX = 'projects/watchloom-canturhan/databases/(default)/documents/';
const ID = 'a'.repeat(20), PARENT = 'b'.repeat(20);
const comment = {schema: 1, contentKey: 'tvmaze:show:123', contentKind: 'series', authorUid: 'authorUid',
  authorName: '@series_fan', body: 'Final harikaydı 🎬 素晴らしい', parentId: null, isSpoiler: true, status: 'pending'};
function fakeClients() {
  const docs = new Map(), users = new Map();
  let commits = 0;
  function seed(location, data) { docs.set(PREFIX + location, {...update(location, data).update,
    updateTime: '2026-11-06T00:00:00.000000Z'}); }
  function assertPrivate(options) { assert.deepEqual(options.skipLog, {body: true, resBody: true, queryParams: true}); }
  const firestore = {
    async get(url, options) {
      assertPrivate(options);
      const name = url.slice(1), found = docs.get(name);
      if (!found) throw Object.assign(new Error('missing'), {status: 404});
      return {body: structuredClone(found)};
    },
    async post(url, body, options) {
      assertPrivate(options);
      if (url.endsWith(':beginTransaction')) return {body: {transaction: 'fixture-transaction'}};
      if (url.endsWith(':rollback')) return {body: {}};
      if (url.endsWith(':runQuery')) {
        assert.equal(body.structuredQuery.from[0].collectionId, 'authors');
        const blockedUid = body.structuredQuery.where.fieldFilter.value.stringValue;
        return {body: [...docs.values()].filter(doc => doc.fields.blockedUid?.stringValue === blockedUid)
          .slice(0, 50).map(document => ({document}))};
      }
      assert.ok(url.endsWith(':commit'), `Unexpected endpoint ${url}`);
      commits++;
      for (const write of body.writes) {
        if (write.delete) { docs.delete(write.delete); continue; }
        const old = docs.get(write.update.name), fields = write.updateMask ? {...old?.fields} : {};
        Object.assign(fields, write.update.fields);
        for (const transform of write.updateTransforms || []) fields[transform.fieldPath] = {timestampValue: '2026-11-06T00:00:00Z'};
        docs.set(write.update.name, {name: write.update.name, fields, updateTime: '2026-11-06T00:00:01Z'});
      }
      return {body: {}};
    },
  };
  const identity = {async post(url, body, options) {
    assertPrivate(options);
    assert.equal(url, '/projects/watchloom-canturhan/accounts:lookup');
    return {body: {users: body.email
      ? [...users.values()].filter(user => body.email.includes(user.email?.toLowerCase()))
      : body.localId.map(uid => users.get(uid)).filter(Boolean)}};
  }};
  return {docs, users, seed, firestore, identity, get commits() { return commits; }};
}
async function quiet(action) {
  const previous = console.log;
  console.log = () => {};
  try { return await action(); } finally { console.log = previous; }
}
test('operator identifiers reject emails, path traversal and malformed content IDs', () => {
  assert.equal(validUid('firebase_UID-123'), 'firebase_UID-123');
  for (const uid of ['', 'owner@example.com', 'uid/other', '..', 'x'.repeat(129), 'FIREBASE_UID', 'NEW_FIREBASE_UID']) assert.throws(() => validUid(uid));
  assert.equal(validId(ID), ID);
  for (const id of ['short', '../documents/secrets', `${ID}/other`]) assert.throws(() => validId(id));
});
test('moderator setup requires enabled verified Auth identity, not just a matching email', () => {
  assert.equal(verifiedAccount({email: 'owner@example.com'}), false);
  assert.equal(verifiedAccount({emailVerified: true}), true);
  assert.equal(verifiedAccount({emailVerified: true, disabled: true}), false);
  assert.equal(verifiedAccount({providerUserInfo: [{providerId: 'apple.com'}]}), true);
  assert.deepEqual(privateOptions().skipLog, {body: true, resBody: true, queryParams: true});
});
test('approval validation protects identity/body/content boundaries without rejecting international text', () => {
  assert.equal(safeToApprove(comment), true);
  for (const patch of [{status: 'approved'}, {contentKind: 'movie'}, {contentKey: 'local:123'},
    {authorName: 'user@example.com'}, {authorName: '<hostile>'}, {body: 'safe\u200Bhidden'},
    {body: 'safe\u202Ehidden'}, {body: 'https://unsafe.test'}, {body: 'fuck you'}, {parentId: '../other'}]) {
    assert.equal(safeToApprove({...comment, ...patch}), false, JSON.stringify(patch));
  }
});
test('init fails without explicit moderation responsibility or a real verified UID', async () => {
  const fake = fakeClients();
  await assert.rejects(run(['init', 'ownerUid'], fake), /responsibility/);
  await assert.rejects(run(['init', 'ownerUid', '--accept-moderation-responsibility'], fake), /verified/);
  assert.equal(fake.commits, 0);
});
test('placeholder and malformed/ambiguous email arguments fail before remote access', async () => {
  assert.equal(validEmail(' Owner@Example.com '), 'owner@example.com');
  for (const email of ['', 'owner', 'owner@example.com\nother@example.com', '--accept-moderation-responsibility']) {
    assert.throws(() => validEmail(email));
  }
  const fake = fakeClients();
  await assert.rejects(run(['init', 'FIREBASE_UID', '--accept-moderation-responsibility'], fake), /placeholder/);
  await assert.rejects(run(['init', '--email', '--accept-moderation-responsibility'], fake), /email/);
  await assert.rejects(run(['init', 'ownerUid', '--email', 'owner@example.com', '--accept-moderation-responsibility'], fake), /either a UID/);
  await assert.rejects(run(['init', '--email', 'owner@example.com'], fake), /responsibility/);
  assert.equal(fake.commits, 0);
});
test('owner email lookup grants only a uniquely resolved verified Auth UID and persists no email', async () => quiet(async () => {
  const fake = fakeClients();
  const email = 'owner@example.com';
  fake.users.set('resolvedUid', {localId: 'resolvedUid', email, emailVerified: true});
  await run(['init', '--email', 'Owner@Example.com', '--accept-moderation-responsibility'], fake);
  const config = fake.docs.get(PREFIX + 'communityConfig/current');
  assert.equal(config.fields.primaryModeratorUid.stringValue, 'resolvedUid');
  assert.equal(config.fields.enabled.booleanValue, true);
  assert.equal(fake.docs.get(PREFIX + 'communityModerators/resolvedUid').fields.active.booleanValue, true);
  assert.equal(JSON.stringify([...fake.docs.values()]).includes(email), false);
}));
test('missing, duplicate, unverified and disabled email matches cannot initialize moderation', async () => {
  for (const accounts of [[], [{localId: 'uidA', emailVerified: false}],
    [{localId: 'uidA', emailVerified: true, disabled: true}],
    [{localId: 'uidA', emailVerified: true}, {localId: 'uidB', emailVerified: true}]]) {
    const fake = fakeClients();
    for (const account of accounts) fake.users.set(account.localId, {...account, email: 'owner@example.com'});
    await assert.rejects(run(['init', '--email', 'owner@example.com', '--accept-moderation-responsibility'], fake),
      /No Watchloom account|More than one|enabled and verified/);
    assert.equal(fake.commits, 0);
  }
});
test('email input cannot bypass the canonical UID verification with a mismatched lookup response', async () => {
  const fake = fakeClients();
  fake.identity.post = async (_, body) => ({body: {users: body.email
    ? [{localId: 'resolvedUid', email: 'other@example.com', emailVerified: true}] : []}});
  await assert.rejects(run(['init', '--email', 'owner@example.com', '--accept-moderation-responsibility'], fake), /No Watchloom account/);
  assert.equal(fake.commits, 0);
});
test('revoked primary moderator can be replaced and resumed without bypassing verification', async () => quiet(async () => {
  const fake = fakeClients();
  for (const uid of ['firstUid', 'replacementUid']) fake.users.set(uid, {localId: uid, emailVerified: true});
  await run(['init', 'firstUid', '--accept-moderation-responsibility'], fake);
  await run(['revoke', 'firstUid'], fake);
  assert.equal(fake.docs.get(PREFIX + 'communityConfig/current').fields.enabled.booleanValue, false);
  await run(['grant', 'replacementUid'], fake);
  await assert.rejects(run(['resume', '--accept-moderation-responsibility'], fake), /Initialize/);
  await run(['set-primary', 'replacementUid', '--accept-moderation-responsibility'], fake);
  assert.equal(fake.docs.get(PREFIX + 'communityConfig/current').fields.enabled.booleanValue, false);
  await run(['resume', '--accept-moderation-responsibility'], fake);
  assert.equal(fake.docs.get(PREFIX + 'communityConfig/current').fields.enabled.booleanValue, true);
  assert.equal(fake.docs.get(PREFIX + 'communityConfig/current').fields.primaryModeratorUid.stringValue, 'replacementUid');
}));
test('delayed reply approval rechecks mutual blocks and parent deletion markers', async () => quiet(async () => {
  const fake = fakeClients();
  for (const uid of ['moderatorUid', 'authorUid']) fake.users.set(uid, {localId: uid, emailVerified: true});
  fake.seed('communityConfig/current', {enabled: true, moderationReady: true, rulesVersion: 1, primaryModeratorUid: 'moderatorUid'});
  fake.seed('communityModerators/moderatorUid', {active: true});
  fake.seed(`communityComments/${ID}`, {...comment, parentId: PARENT});
  fake.seed(`communityComments/${PARENT}`, {...comment, authorUid: 'parentUid', parentId: null, status: 'approved'});
  fake.seed('communityProfiles/authorUid', {acceptedPolicyVersion: '2026-11-05'});
  fake.seed('users/authorUid', {status: 'active'});
  fake.seed('communityBlocks/parentUid/authors/authorUid', {blockedUid: 'authorUid'});
  await assert.rejects(run(['approve', ID, '--reason', 'acceptable'], fake), /blocked/);
  fake.docs.delete(PREFIX + 'communityBlocks/parentUid/authors/authorUid');
  fake.seed('deletionMarkers/parentUid', {startedAt: new Date()});
  await assert.rejects(run(['approve', ID, '--reason', 'acceptable'], fake), /deleting/);
  fake.docs.delete(PREFIX + 'deletionMarkers/parentUid');
  await run(['approve', ID, '--reason', 'acceptable'], fake);
  assert.equal(fake.docs.get(PREFIX + `communityComments/${ID}`).fields.status.stringValue, 'approved');
}));
test('report resolution removes global report and private pointer atomically without copying PII', async () => quiet(async () => {
  const fake = fakeClients();
  fake.seed(`communityReports/${ID}`, {commentId: PARENT, reporterUid: 'reporterUid', reason: 'spam'});
  fake.seed(`users/reporterUid/communityReportRefs/${ID}`, {reportId: ID});
  await run(['resolve-report', ID, '--reason', 'actioned'], fake);
  assert.equal(fake.docs.has(PREFIX + `communityReports/${ID}`), false);
  assert.equal(fake.docs.has(PREFIX + `users/reporterUid/communityReportRefs/${ID}`), false);
  const events = [...fake.docs.values()].filter(doc => doc.name.includes('communityModerationEvents/'));
  assert.equal(events.length, 1);
  assert.equal(JSON.stringify(events).includes('reporterUid'), false);
  assert.equal(fake.commits, 1);
}));
test('incoming block cleanup requires Auth absence and never deletes outside communityBlocks', async () => quiet(async () => {
  const fake = fakeClients();
  fake.users.set('deletedUid', {localId: 'deletedUid', emailVerified: true});
  fake.seed('communityBlocks/oneUid/authors/deletedUid', {blockedUid: 'deletedUid'});
  fake.seed('communityBlocks/twoUid/authors/deletedUid', {blockedUid: 'deletedUid'});
  fake.seed('communityBlocks/twoUid/authors/otherUid', {blockedUid: 'otherUid'});
  await assert.rejects(run(['purge-deleted', 'deletedUid'], fake), /still exists/);
  assert.equal(fake.commits, 0);
  fake.users.delete('deletedUid');
  fake.seed('otherFeature/group/authors/deletedUid', {blockedUid: 'deletedUid'});
  await assert.rejects(run(['purge-deleted', 'deletedUid'], fake), /Unexpected collection/);
  assert.equal(fake.commits, 0);
  fake.docs.delete(PREFIX + 'otherFeature/group/authors/deletedUid');
  await run(['purge-deleted', 'deletedUid'], fake);
  assert.equal(fake.docs.has(PREFIX + 'communityBlocks/oneUid/authors/deletedUid'), false);
  assert.equal(fake.docs.has(PREFIX + 'communityBlocks/twoUid/authors/deletedUid'), false);
  assert.equal(fake.docs.has(PREFIX + 'communityBlocks/twoUid/authors/otherUid'), true);
}));
