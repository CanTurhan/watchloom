'use strict';
// Owner-operated Spark moderation. OAuth is held only inside the official CLI;
// no service-account key/token is bundled and app-writable roles are not trusted.
// An owner-only email lookup resolves an existing Auth UID; verification and
// persisted roles still use that UID, never an email supplied by an app client.
const path = require('node:path');
const crypto = require('node:crypto');
const {check} = require('./check_firebase_spark.cjs');
const PROJECT = 'watchloom-canturhan';
const POLICY = '2026-11-05';
const PREFIX = `projects/${PROJECT}/databases/(default)/documents/`;
const REASONS = ['acceptable', 'abuse', 'hate', 'sexual', 'spam', 'spoiler', 'personalInformation', 'other'];
function privateOptions(queryParams) {
  return {skipLog: {body: true, resBody: true, queryParams: true}, ...(queryParams ? {queryParams} : {})};
}
function validUid(uid) {
  if (/^(?:FIREBASE_UID|NEW_FIREBASE_UID|DELETED_FIREBASE_UID|YOUR_FIREBASE_UID)$/i.test(uid || '')) {
    throw new Error('FIREBASE_UID is a placeholder. Use your actual Watchloom Auth UID, or: init --email your-account-email --accept-moderation-responsibility');
  }
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid || '')) throw new Error('Use a Firebase Authentication UID, never an email address.');
  return uid;
}
function validEmail(email) {
  const normalized = typeof email === 'string' ? email.trim().toLowerCase() : '';
  if (normalized.length > 320 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) {
    throw new Error('Use the email of an existing Watchloom account after --email. Sign in to the app first.');
  }
  return normalized;
}
function validId(id) {
  if (!/^[A-Za-z0-9]{20}$/.test(id || '')) throw new Error('A 20-character comment/report ID is required.');
  return id;
}
function value(v) {
  if (v === null) return {nullValue: null};
  if (typeof v === 'boolean') return {booleanValue: v};
  if (Number.isInteger(v)) return {integerValue: `${v}`};
  if (v instanceof Date) return {timestampValue: v.toISOString()};
  return {stringValue: String(v)};
}
function decode(v) {
  if ('nullValue' in v) return null;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('booleanValue' in v) return v.booleanValue;
  return v.stringValue ?? v.timestampValue ?? null;
}
function document(doc) {
  return doc ? {id: doc.name.slice(PREFIX.length), updateTime: doc.updateTime,
    data: Object.fromEntries(Object.entries(doc.fields || {}).map(([key, v]) => [key, decode(v)]))} : null;
}
function update(location, data, {patch = false, timestamps = []} = {}) {
  return {update: {name: PREFIX + location,
    fields: Object.fromEntries(Object.entries(data).map(([key, v]) => [key, value(v)]))},
  ...(patch ? {updateMask: {fieldPaths: Object.keys(data)}} : {}),
  ...(timestamps.length ? {updateTransforms: timestamps.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {})};
}
function event(action, targetId, reason) {
  return update(`communityModerationEvents/${crypto.randomBytes(10).toString('hex')}`,
    {action, targetId, reason, source: 'owner-cli'}, {timestamps: ['createdAt']});
}
function verifiedAccount(user) {
  return !!user && !user.disabled && (user.emailVerified === true ||
    user.providerUserInfo?.some(provider => ['apple.com', 'google.com'].includes(provider.providerId)) === true);
}
function safeToApprove(data) {
  return data?.schema === 1 && data.status === 'pending' && data.contentKind === 'series'
    && /^tvmaze:show:[1-9][0-9]{0,9}$/.test(data.contentKey || '')
    && typeof data.authorUid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(data.authorUid)
    && typeof data.authorName === 'string'
    && (/^@[a-z][a-z0-9_]{2,19}$/.test(data.authorName) || /^[\p{L}\p{M}\p{N} _-]{3,24}$/u.test(data.authorName))
    && typeof data.body === 'string' && data.body.length >= 1 && data.body.length <= 1200
    && /^[\p{L}\p{M}\p{N}\p{P}\p{S} \n]+$/u.test(data.body)
    && !/(https?\s*:|www\s*\.|@)/i.test(data.body)
    && !/(^|[^a-z])(fuck|shit|bitch|nigger|nigga|cunt|orospu|siktir|sikik|amk|aq)([^a-z]|$)/i.test(data.body)
    && typeof data.isSpoiler === 'boolean'
    && (data.parentId === null || /^[A-Za-z0-9]{20}$/.test(data.parentId));
}
async function run(args, clients) {
  const [command = 'status', suppliedTarget] = args;
  let target = suppliedTarget;
  let accountEmail;
  const commands = ['status', 'init', 'init-owner', 'grant', 'revoke', 'set-primary', 'pause', 'resume', 'pending', 'reports', 'approve', 'reject', 'remove', 'resolve-report', 'maintenance', 'purge-deleted'];
  if (!commands.includes(command)) throw new Error('Unknown command. Run --help.');
  const emailIndex = args.indexOf('--email');
  if (emailIndex !== -1) {
    if (!['init', 'grant', 'set-primary'].includes(command) || emailIndex !== 1 ||
        args.indexOf('--email', emailIndex + 1) !== -1) {
      throw new Error('Use either a UID or --email EMAIL, not both. Email lookup is only available for init, grant and set-primary.');
    }
    accountEmail = validEmail(args[emailIndex + 1]);
    target = undefined;
  }
  if (!accountEmail && ['init', 'grant', 'revoke', 'set-primary', 'purge-deleted'].includes(command)) validUid(target);
  if (['approve', 'reject', 'remove', 'resolve-report'].includes(command)) validId(target);
  if (['init', 'init-owner', 'resume', 'set-primary'].includes(command) && !args.includes('--accept-moderation-responsibility')) {
    throw new Error('Read firebase/COMMUNITY_MODERATION.md and explicitly pass --accept-moderation-responsibility.');
  }
  const reasonIndex = args.indexOf('--reason');
  const reason = reasonIndex >= 0 ? args[reasonIndex + 1] : null;
  if (['approve', 'reject', 'remove'].includes(command) &&
      (!REASONS.includes(reason) || (command === 'approve') !== (reason === 'acceptable'))) {
    throw new Error(`Use --reason ${command === 'approve' ? 'acceptable' : REASONS.filter(x => x !== 'acceptable').join('|')}.`);
  }
  if (command === 'resolve-report' && !['actioned', 'noViolation', 'duplicate'].includes(reason)) {
    throw new Error('Use --reason actioned|noViolation|duplicate.');
  }
  let firestore, identity;
  if (clients) ({firestore, identity} = clients);
  else {
    const {root} = await check(PROJECT);
    const {Client} = require(path.join(root, 'lib/apiv2'));
    firestore = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1'});
    identity = new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'v1'});
  }
  const endpoint = `/projects/${PROJECT}/databases/(default)/documents`;
  async function get(location, transaction) {
    try { return document((await firestore.get(`${endpoint}/${location}`, privateOptions(transaction ? {transaction} : undefined))).body); }
    catch (error) { if (error.status === 404) return null; throw error; }
  }
  const commit = (writes, transaction) => firestore.post(`${endpoint}:commit`, {writes, ...(transaction ? {transaction} : {})}, privateOptions());
  async function transaction(action) {
    const token = (await firestore.post(`${endpoint}:beginTransaction`, {}, privateOptions())).body.transaction;
    try { await action(token); }
    catch (error) {
      try { await firestore.post(`${endpoint}:rollback`, {transaction: token}, privateOptions()); } catch (_) {}
      throw error;
    }
  }
  async function requireAuthUid(uid) {
    const users = (await identity.post(`/projects/${PROJECT}/accounts:lookup`, {localId: [validUid(uid)]}, privateOptions())).body.users;
    const user = users?.find(item => item.localId === uid);
    if (!verifiedAccount(user)) throw new Error('Moderator UID must exist, be enabled, and have a verified email or Apple/Google provider.');
  }
  if (accountEmail) {
    const users = (await identity.post(`/projects/${PROJECT}/accounts:lookup`,
      {email: [accountEmail]}, privateOptions())).body.users || [];
    const matching = users.filter(user => typeof user.email === 'string' && user.email.toLowerCase() === accountEmail);
    if (matching.length !== 1) {
      throw new Error(matching.length === 0
        ? 'No Watchloom account matches this email. Sign in to Watchloom with it first. If Apple hides your email, use the actual UID from Firebase Authentication instead.'
        : 'More than one Auth account matches; select the exact UID from Firebase Authentication. Nothing was changed.');
    }
    if (!verifiedAccount(matching[0])) {
      throw new Error('The Watchloom account must be enabled and verified. Verify its email or sign in with Apple/Google. Nothing was changed.');
    }
    target = validUid(matching[0].localId);
  }
  async function ready(token) {
    const config = (await get('communityConfig/current', token))?.data;
    if (!config?.moderationReady || config.rulesVersion !== 1) {
      throw new Error('Initialize a real moderator first. Nothing published.');
    }
    // Only the owner CLI can write this configuration or approve content: the
    // Google OAuth/IAM permission is enforced by Firestore for every request.
    // An app Auth account is not required for that private operator workflow.
    if (config.operatorType === 'owner-cli' && config.primaryModeratorUid === null) return config;
    if (!config.primaryModeratorUid) throw new Error('Initialize a real moderator first. Nothing published.');
    const mod = (await get(`communityModerators/${validUid(config.primaryModeratorUid)}`, token))?.data;
    if (mod?.active !== true) throw new Error('Primary moderator is inactive. Nothing published.');
    await requireAuthUid(config.primaryModeratorUid);
    return config;
  }
  async function list(collection, filters = [], {olderThan, cursor} = {}) {
    const clauses = [...filters];
    if (olderThan) clauses.push({fieldFilter: {field: {fieldPath: 'createdAt'}, op: 'LESS_THAN', value: value(olderThan)}});
    const structuredQuery = {from: [{collectionId: collection}], limit: 50,
      orderBy: [{field: {fieldPath: 'createdAt'}, direction: 'ASCENDING'}, {field: {fieldPath: '__name__'}, direction: 'ASCENDING'}],
      ...(clauses.length ? {where: clauses.length === 1 ? clauses[0] : {compositeFilter: {op: 'AND', filters: clauses}}} : {})};
    if (cursor) {
      let saved;
      try { saved = JSON.parse(Buffer.from(cursor, 'base64url').toString()); } catch (_) { throw new Error('Invalid page cursor.'); }
      if (!saved?.time || !/^[A-Za-z0-9]{20}$/.test(saved.id) || !Number.isFinite(Date.parse(saved.time))) throw new Error('Invalid page cursor.');
      structuredQuery.startAt = {before: false, values: [{timestampValue: saved.time}, {referenceValue: PREFIX + collection + '/' + saved.id}]};
    }
    const rows = (await firestore.post(`${endpoint}:runQuery`, {structuredQuery}, privateOptions())).body;
    return (rows || []).filter(row => row.document).map(row => document(row.document));
  }
  const statusFilter = status => ({fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: value(status)}});
  if (command === 'status') {
    const config = (await get('communityConfig/current'))?.data;
    const mod = config?.primaryModeratorUid ? (await get(`communityModerators/${validUid(config.primaryModeratorUid)}`))?.data : null;
    console.log(JSON.stringify({project: PROJECT, configured: !!config, enabled: config?.enabled === true,
      moderationReady: config?.moderationReady === true, rulesVersion: config?.rulesVersion || null,
      operatorType: config?.operatorType || (config?.primaryModeratorUid ? 'firebase-user' : null),
      ...(config?.operatorType === 'owner-cli'
        ? {ownerCliModeration: config.primaryModeratorUid === null}
        : {primaryModeratorActive: mod?.active === true})}, null, 2));
    return;
  }
  if (command === 'init-owner') {
    await transaction(async token => {
      if (await get('communityConfig/current', token)) {
        throw new Error('Already initialized; inspect status and use resume or set-primary instead.');
      }
      await commit([update('communityConfig/current', {enabled: true, moderationReady: true,
        rulesVersion: 1, operatorType: 'owner-cli', primaryModeratorUid: null,
        acceptedPolicyVersion: POLICY}, {timestamps: ['updatedAt']}),
      event('init-owner', 'owner-cli', 'ownerConfigured')], token);
    });
  } else if (['init', 'grant', 'set-primary'].includes(command)) {
    await requireAuthUid(target);
    await transaction(async token => {
      const previous = await get('communityConfig/current', token);
      if (command === 'init' && previous) throw new Error('Already initialized; use grant/resume instead.');
      if (command === 'set-primary' && !previous) throw new Error('Initialize the community first.');
      const writes = [update(`communityModerators/${target}`, {active: true}, {timestamps: ['updatedAt']})];
      if (command === 'init') writes.push(update('communityConfig/current', {enabled: true, moderationReady: true,
        rulesVersion: 1, operatorType: 'firebase-user', primaryModeratorUid: target, acceptedPolicyVersion: POLICY}, {timestamps: ['updatedAt']}));
      if (command === 'set-primary') writes.push(update('communityConfig/current', {enabled: false,
        moderationReady: true, operatorType: 'firebase-user', primaryModeratorUid: target}, {patch: true, timestamps: ['updatedAt']}));
      writes.push(event(command, target, 'ownerConfigured'));
      await commit(writes, token);
    });
  } else if (command === 'revoke') {
    await transaction(async token => {
      const config = (await get('communityConfig/current', token))?.data;
      const writes = [update(`communityModerators/${target}`, {active: false}, {timestamps: ['updatedAt']})];
      if (config?.primaryModeratorUid === target) writes.push(update('communityConfig/current',
        {enabled: false, moderationReady: false}, {patch: true, timestamps: ['updatedAt']}));
      writes.push(event('revoke', target, 'ownerConfigured'));
      await commit(writes, token);
    });
  } else if (['pause', 'resume'].includes(command)) {
    await transaction(async token => {
      if (command === 'resume') await ready(token);
      else if (!(await get('communityConfig/current', token))) throw new Error('No configuration exists.');
      await commit([update('communityConfig/current', {enabled: command === 'resume'},
        {patch: true, timestamps: ['updatedAt']}), event(command, 'community', 'ownerConfigured')], token);
    });
  } else if (['pending', 'reports'].includes(command)) {
    const index = args.indexOf('--cursor');
    const collection = command === 'pending' ? 'communityComments' : 'communityReports';
    const rows = await list(collection, command === 'pending' ? [statusFilter('pending')] : [],
      {cursor: index >= 0 ? args[index + 1] : undefined});
    const last = rows.at(-1);
    console.log(JSON.stringify({items: rows, nextCursor: rows.length === 50 ? Buffer.from(JSON.stringify({
      time: last.data.createdAt, id: last.id.split('/').at(-1)})).toString('base64url') : null}, null, 2));
    console.log('Private moderation material: do not paste this output into public issues, chats or logs.');
  } else if (['approve', 'reject', 'remove'].includes(command)) {
    await transaction(async token => {
      const location = `communityComments/${target}`;
      const existing = await get(location, token);
      if (!existing) throw new Error('Comment no longer exists; no action needed.');
      if (command === 'approve') {
        const config = await ready(token);
        if (!config.enabled) throw new Error('Publishing is paused.');
        const data = existing.data;
        if (!safeToApprove(data)) throw new Error('Malformed/non-pending comment; reject or remove it.');
        const marker = await get(`deletionMarkers/${data.authorUid}`, token);
        const profile = (await get(`communityProfiles/${data.authorUid}`, token))?.data;
        const account = (await get(`users/${data.authorUid}`, token))?.data;
        if (marker || !profile || profile.acceptedPolicyVersion !== POLICY || account?.status !== 'active') {
          throw new Error('Author is deleting, missing, or has not accepted the current policy; do not publish.');
        }
        await requireAuthUid(data.authorUid);
        if (data.parentId) {
          const parent = (await get(`communityComments/${data.parentId}`, token))?.data;
          if (!parent || parent.status !== 'approved' || parent.parentId !== null || parent.contentKey !== data.contentKey) {
            throw new Error('Reply root is unavailable or belongs to another series. Reject or remove the orphaned pending reply.');
          }
          const parentMarker = await get(`deletionMarkers/${validUid(parent.authorUid)}`, token);
          const blockedByAuthor = await get(`communityBlocks/${data.authorUid}/authors/${parent.authorUid}`, token);
          const blockedByParent = await get(`communityBlocks/${parent.authorUid}/authors/${data.authorUid}`, token);
          if (parentMarker || blockedByAuthor || blockedByParent) throw new Error('Reply participants are deleting or blocked; do not publish.');
        }
      }
      const writes = command === 'remove' ? [{delete: PREFIX + location}] : [update(location,
        {status: command === 'approve' ? 'approved' : 'rejected', moderationReason: reason},
        {patch: true, timestamps: ['moderatedAt']})];
      writes.push(event(command, target, reason));
      await commit(writes, token);
    });
  } else if (command === 'resolve-report') {
    await transaction(async token => {
      const report = await get(`communityReports/${target}`, token);
      if (!report) throw new Error('Report no longer exists; no action needed.');
      const uid = validUid(report.data.reporterUid);
      await commit([{delete: PREFIX + `communityReports/${target}`},
        {delete: PREFIX + `users/${uid}/communityReportRefs/${target}`}, event('resolve-report', target, reason)], token);
    });
  } else if (command === 'purge-deleted') {
    const users = (await identity.post(`/projects/${PROJECT}/accounts:lookup`, {localId: [target]}, privateOptions())).body.users;
    if (users?.some(user => user.localId === target)) throw new Error('Auth account still exists; finish normal account deletion first.');
    let removed = 0;
    while (true) {
      const rows = (await firestore.post(`${endpoint}:runQuery`, {structuredQuery: {
        from: [{collectionId: 'authors', allDescendants: true}], limit: 50,
        where: {fieldFilter: {field: {fieldPath: 'blockedUid'}, op: 'EQUAL', value: value(target)}},
      }}, privateOptions())).body;
      const records = (rows || []).filter(row => row.document).map(row => document(row.document));
      if (!records.length) break;
      // Never delete an unrelated collection with the same group name.
      if (records.some(record => !new RegExp(`^communityBlocks/[A-Za-z0-9_-]{1,128}/authors/${target}$`).test(record.id))) {
        throw new Error('Unexpected collection-group record; no page was deleted. Inspect privately.');
      }
      await commit(records.map(record => ({delete: PREFIX + record.id,
        currentDocument: {updateTime: record.updateTime}})));
      removed += records.length;
    }
    console.log(`Removed ${removed} private suppression preferences for the deleted account; no block owners were printed.`);
  } else if (command === 'maintenance') {
    // Bounded manual retention, no paid TTL or scheduled Cloud Functions.
    for (const [collection, days, filters] of [
      ['communityComments', 30, [statusFilter('pending')]],
      ['communityComments', 30, [statusFilter('rejected')]],
      ['communityReports', 90, []], ['communityModerationEvents', 90, []],
    ]) {
      let deleted = 0;
      while (true) {
        const rows = await list(collection, filters, {olderThan: new Date(Date.now() - days * 86400000)});
        if (!rows.length) break;
        const writes = [];
        for (const row of rows) {
          writes.push({delete: PREFIX + row.id, currentDocument: {updateTime: row.updateTime}});
          if (collection === 'communityReports') writes.push({delete: PREFIX + `users/${validUid(row.data.reporterUid)}/communityReportRefs/${row.id.split('/').at(-1)}`});
        }
        await commit(writes);
        deleted += rows.length;
      }
      console.log(`${collection}: removed ${deleted} expired records.`);
    }
  }
  console.log(`${command}: completed in ${PROJECT}.`);
}
function help() {
  console.log(`Watchloom owner-only moderation (Spark, ${PROJECT})
  status
  init-owner --accept-moderation-responsibility
  init FIREBASE_UID --accept-moderation-responsibility
  init --email YOUR_WATCHLOOM_EMAIL --accept-moderation-responsibility
  grant FIREBASE_UID | revoke FIREBASE_UID
  set-primary FIREBASE_UID --accept-moderation-responsibility
  pause | resume --accept-moderation-responsibility
  pending [--cursor VALUE] | reports [--cursor VALUE]
  approve COMMENT_ID --reason acceptable
  reject COMMENT_ID --reason abuse|hate|sexual|spam|spoiler|personalInformation|other
  remove COMMENT_ID --reason abuse|hate|sexual|spam|spoiler|personalInformation|other
  resolve-report REPORT_ID --reason actioned|noViolation|duplicate
  maintenance
  purge-deleted DELETED_FIREBASE_UID
init-owner uses the signed-in owner's Google CLI/IAM permissions; no Watchloom app UID/email is needed.
All Apple, Google and verified email users can submit, and EVERY comment remains pending until owner approval.
Read firebase/COMMUNITY_MODERATION.md before enabling posting. Approve only after reviewing BOTH public name and body.`);
}
module.exports = {run, validUid, validEmail, validId, verifiedAccount, safeToApprove, privateOptions, document, update};
if (require.main === module) {
  if (process.argv.includes('--help')) help();
  else run(process.argv.slice(2)).catch(error => {
    // Never echo the response/request (may contain comment text or OAuth data).
    console.error(error.context || error.original
      ? `Moderation stopped (${error.status || 'network'}). Check Firebase CLI login/reauth, owner IAM and connectivity; no successful operation was verified.`
      : error.message);
    process.exitCode = 1;
  });
}
