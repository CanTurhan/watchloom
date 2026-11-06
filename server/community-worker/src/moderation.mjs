import {POLICY, RELEASE, commentId, ready, trustedAuthor, localReason, moderationVerdict} from './policy.mjs';
import {Store, ServiceError, lookupUser, jsonFetch} from './google.mjs';

export class ModerationService {
  constructor(env, dependencies = {}) {
    this.env = env;
    this.store = dependencies.store || new Store(env);
    this.lookup = dependencies.lookup || (uid => lookupUser(env, uid));
    this.classify = dependencies.classify || (async data => {
      if (!env.OPENAI_API_KEY || env.OPENAI_MODEL !== 'omni-moderation-latest') throw new ServiceError();
      const result = await jsonFetch('https://api.openai.com/v1/moderations', {method: 'POST',
        headers: {Authorization: `Bearer ${env.OPENAI_API_KEY}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({model: env.OPENAI_MODEL, input: [data.body, data.authorName]})});
      return moderationVerdict(result);
    });
  }
  async context(data, tx) {
    if (!data?.authorUid) return {valid: false};
    const s = this.store;
    const [root, profile, deleted] = await Promise.all([
      s.get(`users/${data.authorUid}`, tx), s.get(`communityProfiles/${data.authorUid}`, tx),
      s.get(`deletionMarkers/${data.authorUid}`, tx)]);
    if (root?.data.status !== 'active' || deleted || profile?.data.acceptedPolicyVersion !== POLICY) return {valid: false};
    if (data.parentId !== null) {
      const parent = await s.get(`communityComments/${data.parentId}`, tx);
      if (!parent || parent.data.status !== 'approved' || parent.data.contentKey !== data.contentKey
        || parent.data.parentId !== null) return {valid: false};
      const [marker, blockA, blockB] = await Promise.all([
        s.get(`deletionMarkers/${parent.data.authorUid}`, tx),
        s.get(`communityBlocks/${data.authorUid}/authors/${parent.data.authorUid}`, tx),
        s.get(`communityBlocks/${parent.data.authorUid}/authors/${data.authorUid}`, tx)]);
      if (marker || blockA || blockB) return {valid: false};
    }
    return {valid: true};
  }
  async process(id, {viewerUid = null, report = null} = {}) {
    if (!commentId(id) || (report && !commentId(report.path.split('/').at(-1)))) throw new ServiceError('invalid_request', 400);
    const s = this.store, now = new Date(), lease = crypto.randomUUID();
    const jobPath = `communityAutomationJobs/${report ? 'report_' + report.path.split('/').at(-1) : id}`;
    const budgetPath = `communityAutomationBudgets/${now.toISOString().slice(0, 10)}`;
    const claim = await s.transaction(async tx => {
      const [config, comment, job, budget, currentReport] = await Promise.all([
        s.get('communityConfig/current', tx), s.get(`communityComments/${id}`, tx), s.get(jobPath, tx), s.get(budgetPath, tx),
        report ? s.get(report.path, tx) : null]);
      if (!ready(report ? {...config?.data, enabled: true} : config?.data)) throw new ServiceError('community_unavailable');
      if (viewerUid && comment?.data.authorUid !== viewerUid) throw new ServiceError('forbidden', 403);
      if (report && (!currentReport || currentReport.data.commentId !== id
        || currentReport.data.reporterUid !== report.data.reporterUid)) return {done: true, status: 'removed'};
      if (!comment || comment.data.status !== (report ? 'approved' : 'pending')) return {done: true, status: comment?.data.status || 'removed'};
      if (job?.data.leaseUntil > now || job?.data.nextAttemptAt > now) return {done: true, status: 'pending'};
      const maximum = Math.min(500, Math.max(1, Number(this.env.DAILY_MODERATION_LIMIT) || 500));
      const reserve = Math.min(50, Math.floor(maximum * 0.1));
      if ((budget?.data.count || 0) >= (report ? maximum : maximum - reserve)) return {done: true, status: 'pending'};
      const context = await this.context(comment.data, tx);
      let reason = localReason(comment.data);
      if (!context.valid) reason = 'accountUnavailable';
      if (comment.data.policyVersion !== POLICY) reason = 'consentRequired';
      const attempt = (job?.data.attempt || 0) + 1;
      const leaseUntil = new Date(now.getTime() + 90000);
      await s.commit([
        s.set(jobPath, {commentId: id, lease, leaseUntil, nextAttemptAt: now,
          attempt, state: 'processing', updatedAt: now}, false),
        s.set(budgetPath, {count: (budget?.data.count || 0) + 1, updatedAt: now}, false),
        s.set(report ? report.path : `communityComments/${id}`, {moderationNextAt: leaseUntil}),
      ], tx);
      return {data: comment.data, reason, attempt};
    });
    if (claim.done) return {status: claim.status};
    let verdict;
    try {
      if (claim.reason) verdict = {status: 'rejected', reason: claim.reason, model: 'local-policy'};
      else if (!trustedAuthor(await this.lookup(claim.data.authorUid))) {
        verdict = {status: 'rejected', reason: 'accountUnavailable', model: 'account-check'};
      } else verdict = await this.classify(claim.data);
      // Dependency implementations must also obey the fail-closed contract.
      if (!['approved', 'rejected'].includes(verdict?.status) || typeof verdict.model !== 'string'
        || (verdict.status === 'rejected' && typeof verdict.reason !== 'string')) throw new ServiceError();
      if (verdict.status === 'approved' && !trustedAuthor(await this.lookup(claim.data.authorUid))) {
        verdict = {status: 'rejected', reason: 'accountUnavailable', model: 'account-check'};
      }
      return await s.transaction(async tx => {
        const [current, job, config] = await Promise.all([s.get(`communityComments/${id}`, tx),
          s.get(jobPath, tx), s.get('communityConfig/current', tx)]);
        if (!current || current.data.status !== (report ? 'approved' : 'pending')
          || job?.data.lease !== lease) return {status: current?.data.status || 'removed'};
        if (!ready(report ? {...config?.data, enabled: true} : config?.data)) throw new ServiceError('community_unavailable');
        // Never publish a stale name/body after moderation or account deletion.
        if (current.data.body !== claim.data.body || current.data.authorName !== claim.data.authorName
          || current.data.authorUid !== claim.data.authorUid || current.data.policyVersion !== claim.data.policyVersion
          || current.data.contentKey !== claim.data.contentKey || current.data.contentKind !== claim.data.contentKind
          || current.data.parentId !== claim.data.parentId || current.data.isSpoiler !== claim.data.isSpoiler) {
          throw new ServiceError('submission_changed');
        }
        const context = await this.context(current.data, tx);
        if (!context.valid && verdict.status === 'approved') verdict = {status: 'rejected', reason: 'accountUnavailable', model: 'account-check'};
        const finished = new Date();
        const patch = {status: verdict.status, moderationReason: verdict.reason || null,
          moderatedAt: finished, moderationSource: 'automatic', moderationModel: verdict.model,
          moderationPolicyVersion: POLICY, scoreSchema: 1,
          upVotes: current.data.upVotes || 0, downVotes: current.data.downVotes || 0,
          score: (current.data.upVotes || 0) - (current.data.downVotes || 0)};
        if (report?.data.reason === 'spoiler' && verdict.status === 'approved') patch.isSpoiler = true;
        const writes = [s.set(`communityComments/${id}`, patch),
          s.set(jobPath, {state: 'complete', leaseUntil: finished, updatedAt: finished}),
          s.set(`communityModerationEvents/${crypto.randomUUID().replaceAll('-', '')}`,
            {action: report ? 'automaticReport' : 'automaticModeration', targetId: id,
              reason: verdict.reason || 'acceptable', source: RELEASE, createdAt: finished}, false)];
        if (report) {
          const latestReport = await s.get(report.path, tx);
          if (latestReport?.data.reporterUid === report.data.reporterUid && latestReport.data.commentId === id) {
            writes.push(s.remove(report.path), s.remove(`users/${report.data.reporterUid}/communityReportRefs/${report.path.split('/').at(-1)}`));
          }
        }
        await s.commit(writes, tx);
        return {status: verdict.status};
      });
    } catch {
      // No timeout, malformed response, rate limit or quota failure is approval.
      const retryAt = new Date(Date.now() + Math.min(3600000, 60000 * 2 ** Math.min(claim.attempt, 6)));
      try {
        await s.transaction(async tx => {
          const [current, job, latestReport] = await Promise.all([s.get(`communityComments/${id}`, tx), s.get(jobPath, tx),
            report ? s.get(report.path, tx) : null]);
          if (!current || job?.data.lease !== lease) return;
          const writes = [s.set(jobPath, {state: 'waiting', leaseUntil: new Date(), nextAttemptAt: retryAt, updatedAt: new Date()})];
          if (!report && current.data.status === 'pending') writes.push(s.set(`communityComments/${id}`, {moderationNextAt: retryAt}));
          if (report && latestReport?.data.reporterUid === report.data.reporterUid) {
            writes.push(s.set(report.path, {moderationNextAt: retryAt}));
          }
          await s.commit(writes, tx);
        });
      } catch { /* Pending state survives; Cron retries after the lease expires. */ }
      return {status: 'pending'};
    }
  }
  async next(now = new Date()) {
    // One job per invocation stays below Workers Free's 50 subrequest limit.
    const s = this.store, reportTurn = Math.floor(now.getTime() / 60000) % 3 === 0;
    if (reportTurn) {
      const reports = await s.query('communityReports', [['moderationNextAt', 'LESS_THAN_OR_EQUAL', now]], 'moderationNextAt');
      if (reports[0]) {
        const report = reports[0];
        const target = await s.get(`communityComments/${report.data.commentId}`);
        if (!target || target.data.status !== 'approved') {
          await s.commit([s.remove(report.path), s.remove(`users/${report.data.reporterUid}/communityReportRefs/${report.path.split('/').at(-1)}`)]);
          return;
        }
        await this.process(report.data.commentId, {report});
        return;
      }
      // Backward-compatible seed for reports created by an older binary. New
      // clients supply a rules-checked server timestamp; old clients still report.
      const legacy = await s.query('communityReports', [], 'createdAt', 10);
      const seed = legacy.filter(row => !(row.data.moderationNextAt instanceof Date));
      if (seed.length) {
        await s.commit(seed.map(row => ({...s.set(row.path, {moderationNextAt: now}),
          currentDocument: {updateTime: row.updateTime}})));
        return;
      }
    }
    const pending = await s.query('communityComments', [['status', 'EQUAL', 'pending'],
      ['policyVersion', 'EQUAL', POLICY], ['moderationNextAt', 'LESS_THAN_OR_EQUAL', now]], 'moderationNextAt');
    if (pending[0]) await this.process(pending[0].path.split('/').at(-1));
  }
  async maintain() {
    const phase = Math.floor(Date.now() / 600000) % 6;
    const schedules = [
      ['communityComments', 'createdAt', 30, [['status', 'EQUAL', 'pending']]],
      ['communityComments', 'createdAt', 30, [['status', 'EQUAL', 'rejected']]],
      ['communityReports', 'createdAt', 90, []],
      ['communityModerationEvents', 'createdAt', 90, []],
      ['communityAutomationJobs', 'updatedAt', 30, []],
      ['communityAutomationBudgets', 'updatedAt', 30, []],
    ];
    const [collection, time, days, filters] = schedules[phase];
    const rows = await this.store.query(collection, [...filters,
      [time, 'LESS_THAN', new Date(Date.now() - days * 86400000)]], time, 10);
    const writes = [];
    for (const row of rows) {
      // Prevent a stale maintenance result from deleting a newly approved post.
      writes.push({...this.store.remove(row.path), currentDocument: {updateTime: row.updateTime}});
      if (collection === 'communityReports') writes.push(this.store.remove(
        `users/${row.data.reporterUid}/communityReportRefs/${row.path.split('/').at(-1)}`));
    }
    if (writes.length) await this.store.commit(writes);
  }
}
