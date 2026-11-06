import {test} from 'node:test';
import assert from 'node:assert/strict';
import {POLICY, localReason, moderationVerdict, ready, endpointValid} from '../src/policy.mjs';
import {ModerationService} from '../src/moderation.mjs';
import worker from '../src/index.mjs';

const id = '12345678901234567890';
const clean = () => ({schema: 1, policyVersion: POLICY, status: 'pending', contentKind: 'series',
  contentKey: 'tvmaze:show:1', authorUid: 'author', authorName: '@series_fan', body: 'Final harikaydı 🎬',
  createdAt: new Date(), parentId: null, isSpoiler: false, scoreSchema: 1, upVotes: 0, downVotes: 0, score: 0});
const config = () => ({enabled: true, moderationReady: true, rulesVersion: 2,
  moderationMode: 'automatic', acceptedPolicyVersion: POLICY, moderationEndpoint: 'https://watchloom-community.example.workers.dev/'});
const categories = () => ({hate: false, harassment: false, violence: false, sexual: false, 'self-harm': false});
const result = () => ({flagged: false, categories: categories(), category_scores: Object.fromEntries(Object.keys(categories()).map(k => [k, 0.01]))});
function memory() {
  const docs = new Map([
    ['communityConfig/current', config()], [`communityComments/${id}`, clean()],
    ['communityProfiles/author', {acceptedPolicyVersion: POLICY}], ['users/author', {status: 'active'}],
  ]);
  let commits = 0;
  const store = {
    docs, get commits() { return commits; },
    async get(path) { return docs.has(path) ? {path, data: structuredClone(docs.get(path))} : null; },
    set(path, data, merge = true) { return {path, data, merge}; }, remove(path) { return {path, remove: true}; },
    async commit(writes) { commits++; for (const write of writes) {
      if (write.remove) docs.delete(write.path);
      else docs.set(write.path, {...(write.merge ? docs.get(write.path) : {}), ...structuredClone(write.data)});
    } },
    async transaction(action) { return action('local-test-transaction'); },
  };
  return store;
}
function service(store, overrides = {}) {
  let calls = 0;
  return {instance: new ModerationService({DAILY_MODERATION_LIMIT: '500'}, {store,
    lookup: async () => ({emailVerified: true}), classify: async () => {calls++; return {status: 'approved', reason: null, model: 'test-classifier'};},
    ...overrides}), get calls() { return calls; }};
}
test('config needs explicit automatic mode, current policy, safe root endpoint and new rules', () => {
  assert.equal(ready(config()), true);
  for (const patch of [{enabled: false}, {moderationReady: false}, {rulesVersion: 1}, {moderationMode: 'owner-cli'},
    {acceptedPolicyVersion: 'old'}, {moderationEndpoint: 'https://attacker.test/'}]) assert.equal(ready({...config(), ...patch}), false);
  for (const url of ['http://watchloom-community.x.workers.dev/', 'https://x:secret@watchloom-community.x.workers.dev/',
    'https://watchloom-community.x.workers.dev/path', 'https://watchloom-community.x.workers.dev/?token=x',
    'https://watchloom-community.x.workers.dev.evil.test/']) assert.equal(endpointValid(url), false);
});
test('local checks preserve international discussion and public handles, reject abuse/threats/PII/controls', () => {
  for (const body of ['Final harikaydı 🎬', 'Episode 10 was wonderful.', 'İstanbul bölümü çok güzeldi.', '静かな演技が好きでした。']) {
    assert.equal(localReason({...clean(), body}), null);
  }
  for (const body of ['F U C K', 's1kt1r', 'Seni öldürürüm', 'mesaj: private@example.com', 'https ://evil.test',
    'call +90 555 123 45 67', 'spoiler\u202Etext', 'hidden\u200Btext', 'nigger']) assert.ok(localReason({...clean(), body}));
  assert.ok(localReason({...clean(), authorName: '@amk'}));
  assert.ok(localReason({...clean(), policyVersion: 'old'}));
});
test('classification checks BOTH body and public label and never accepts malformed/partial responses', () => {
  const json = {model: 'moderation', results: [result(), result()]};
  assert.equal(moderationVerdict(json).status, 'approved');
  const badName = structuredClone(json); badName.results[1].categories.hate = true;
  assert.equal(moderationVerdict(badName).status, 'rejected');
  for (const value of [null, {}, {...json, results: []}, {...json, results: [result()]},
    {...json, results: [result(), {...result(), flagged: 'false'}]},
    {...json, results: [result(), {...result(), category_scores: {hate: NaN}}]}]) assert.throws(() => moderationVerdict(value));
});
test('verified allowed text is published once with minimal audit data; repeat requests are idempotent', async () => {
  const store = memory(), s = service(store);
  assert.deepEqual(await s.instance.process(id, {viewerUid: 'author'}), {status: 'approved'});
  assert.equal(store.docs.get(`communityComments/${id}`).status, 'approved');
  assert.equal(s.calls, 1);
  assert.equal((await s.instance.process(id, {viewerUid: 'author'})).status, 'approved');
  assert.equal(s.calls, 1);
  for (const [path, data] of store.docs) if (path.startsWith('communityModerationEvents/')) {
    assert.ok(!('body' in data) && !('authorName' in data) && !('email' in data));
  }
});
test('a different viewer cannot moderate or probe another private pending comment', async () => {
  const store = memory(), s = service(store);
  await assert.rejects(s.instance.process(id, {viewerUid: 'stranger'}), {code: 'forbidden'});
  assert.equal(s.calls, 0); assert.equal(store.commits, 0);
});
test('unsafe names/text are rejected locally before transmission and disabled/unverified authors never publish', async () => {
  for (const patch of [{body: 'siktir'}, {authorName: '@amk'}, {policyVersion: 'old'}]) {
    const store = memory(); Object.assign(store.docs.get(`communityComments/${id}`), patch);
    const s = service(store);
    assert.equal((await s.instance.process(id)).status, 'rejected'); assert.equal(s.calls, 0);
  }
  for (const user of [null, {emailVerified: false}, {disabled: true, emailVerified: true}]) {
    const store = memory(), s = service(store, {lookup: async () => user});
    assert.equal((await s.instance.process(id)).status, 'rejected'); assert.equal(s.calls, 0);
  }
});
test('Apple and Google verified providers work without a disclosed/verified email', async () => {
  for (const providerId of ['apple.com', 'google.com']) {
    const store = memory(), s = service(store, {lookup: async () => ({providerUserInfo: [{providerId}]})});
    assert.equal((await s.instance.process(id)).status, 'approved');
  }
});
test('provider outages, invalid decisions and quota exhaustion remain pending with automatic retry', async () => {
  for (const classify of [async () => {throw new Error('private provider body MUST NOT leak');}, async () => ({status: 'allowed'})]) {
    const store = memory(), s = service(store, {classify});
    assert.equal((await s.instance.process(id)).status, 'pending');
    assert.equal(store.docs.get(`communityComments/${id}`).status, 'pending');
    assert.ok(store.docs.get(`communityComments/${id}`).moderationNextAt > new Date());
    assert.equal((await s.instance.process(id)).status, 'pending');
  }
  const store = memory(); store.docs.set(`communityAutomationBudgets/${new Date().toISOString().slice(0, 10)}`, {count: 500});
  const s = service(store); assert.equal((await s.instance.process(id)).status, 'pending'); assert.equal(s.calls, 0);
});
test('an in-flight lease moves the due timestamp and deleted reports cannot be resurrected by a stale claim', async () => {
  const store = memory();
  const s = service(store, {classify: async () => {
    assert.ok(store.docs.get(`communityComments/${id}`).moderationNextAt > new Date());
    return {status: 'approved', reason: null, model: 'test'};
  }});
  assert.equal((await s.instance.process(id)).status, 'approved');
  store.docs.get(`communityComments/${id}`).status = 'approved';
  const removed = {path: 'communityReports/abcdefghij1234567890', data: {commentId: id, reporterUid: 'deleted-reporter'}};
  const before = store.commits;
  assert.equal((await s.instance.process(id, {report: removed})).status, 'removed');
  assert.equal(store.commits, before);
  assert.equal(store.docs.has(removed.path), false);
});
test('deletion, new block, changed content or pause during classification cannot publish stale content', async () => {
  for (const mutate of [
    docs => docs.set('deletionMarkers/author', {}),
    docs => docs.delete(`communityComments/${id}`),
    docs => { docs.get(`communityComments/${id}`).body = 'Changed text'; },
    docs => { docs.get('communityConfig/current').enabled = false; },
    docs => { docs.get('communityProfiles/author').acceptedPolicyVersion = 'old'; },
  ]) {
    const store = memory(), s = service(store, {classify: async () => {mutate(store.docs); return {status: 'approved', reason: null, model: 'test'};}});
    await s.instance.process(id);
    assert.notEqual(store.docs.get(`communityComments/${id}`)?.status, 'approved');
  }
  const store = memory(), parent = '09876543210987654321';
  store.docs.get(`communityComments/${id}`).parentId = parent;
  store.docs.set(`communityComments/${parent}`, {...clean(), status: 'approved', authorUid: 'parent-author'});
  const s = service(store, {classify: async () => {store.docs.set('communityBlocks/parent-author/authors/author', {});
    return {status: 'approved', reason: null, model: 'test'};}});
  assert.equal((await s.instance.process(id)).status, 'rejected');
});
test('reported harmful posts are hidden automatically and private report references are removed', async () => {
  const store = memory(); store.docs.get(`communityComments/${id}`).status = 'approved';
  const report = {path: 'communityReports/abcdefghij1234567890', data: {commentId: id, reporterUid: 'reporter', reason: 'abuse'}};
  store.docs.set(report.path, report.data);
  store.docs.set('users/reporter/communityReportRefs/abcdefghij1234567890', {reportId: 'abcdefghij1234567890'});
  const s = service(store, {classify: async () => ({status: 'rejected', reason: 'hate', model: 'test'})});
  assert.equal((await s.instance.process(id, {report})).status, 'rejected');
  assert.equal(store.docs.has(report.path), false);
  assert.equal(store.docs.has('users/reporter/communityReportRefs/abcdefghij1234567890'), false);
});
test('an old report in backoff cannot hold a different due report at the queue head', async () => {
  const store = memory(), now = new Date(180000 * Math.floor(Date.now() / 180000));
  store.docs.get(`communityComments/${id}`).status = 'approved';
  const future = {commentId: id, reporterUid: 'reporter1', reason: 'abuse', createdAt: new Date(0), moderationNextAt: new Date(now.getTime() + 3600000)};
  const due = {commentId: id, reporterUid: 'reporter2', reason: 'abuse', createdAt: new Date(1), moderationNextAt: new Date(0)};
  store.docs.set('communityReports/abcdefghij1234567890', future);
  store.docs.set('communityReports/abcdefghij0987654321', due);
  store.query = async (collection, filters, order, limit = 1) => [...store.docs]
    .filter(([path, data]) => path.startsWith(collection + '/') && filters.every(([field, op, value]) =>
      op === 'LESS_THAN_OR_EQUAL' ? data[field] instanceof Date && data[field] <= value : data[field] === value))
    .map(([path, data]) => ({path, data})).sort((a, b) => a.data[order] - b.data[order]).slice(0, limit);
  await service(store).instance.next(now);
  assert.equal(store.docs.has('communityReports/abcdefghij1234567890'), true);
  assert.equal(store.docs.has('communityReports/abcdefghij0987654321'), false);
});
test('report outages advance due time without hiding checked content; reserved quota protects rechecks', async () => {
  const report = {path: 'communityReports/abcdefghij1234567890', data: {commentId: id, reporterUid: 'reporter', reason: 'abuse'}};
  const store = memory(); store.docs.get(`communityComments/${id}`).status = 'approved'; store.docs.set(report.path, report.data);
  const unavailable = service(store, {classify: async () => {throw new Error('temporary');}});
  assert.equal((await unavailable.instance.process(id, {report})).status, 'pending');
  assert.equal(store.docs.get(`communityComments/${id}`).status, 'approved');
  assert.ok(store.docs.get(report.path).moderationNextAt > new Date());
  const reserved = memory();
  reserved.docs.set(`communityAutomationBudgets/${new Date().toISOString().slice(0, 10)}`, {count: 450});
  assert.equal((await service(reserved).instance.process(id)).status, 'pending');
  reserved.docs.get(`communityComments/${id}`).status = 'approved'; reserved.docs.set(report.path, report.data);
  reserved.docs.get('communityConfig/current').enabled = false;
  assert.equal((await service(reserved).instance.process(id, {report})).status, 'approved');
});
test('public HTTP surface gives no credentials, rejects unprotected setup, methods and invalid requests', async () => {
  const health = await worker.fetch(new Request('https://watchloom-community.x.workers.dev/health'), {});
  assert.equal(health.status, 200); assert.equal((await health.json()).policyVersion, POLICY);
  const unknown = await worker.fetch(new Request('https://watchloom-community.x.workers.dev/v1/moderate'), {});
  assert.equal(unknown.status, 404);
  const bad = await worker.fetch(new Request('https://watchloom-community.x.workers.dev/v1/moderate', {method: 'POST', body: 'private'}), {});
  assert.equal(bad.status, 400); assert.deepEqual(await bad.json(), {error: 'invalid_request'});
});
