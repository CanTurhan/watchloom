import {PROJECT, POLICY, RELEASE} from './policy.mjs';
import {account, googleToken, Store} from './google.mjs';
import {ModerationService} from './moderation.mjs';
import {setupFailure} from './diagnostics.mjs';

// Called only after the owner setup token is verified. All AI input is synthetic.
export async function verifySetup(env, endpoint) {
  const store = new Store(env), service = new ModerationService(env);
  let stage = 'server_credentials';
  try {
    account(env);
    stage = 'google_oauth'; await googleToken(env);
    stage = 'firebase_auth'; await service.lookup('watchloom_setup_check');
    stage = 'pending_index';
    await store.query('communityComments', [['status', 'EQUAL', 'pending'],
      ['policyVersion', 'EQUAL', POLICY], ['moderationNextAt', 'LESS_THAN_OR_EQUAL', new Date()]], 'moderationNextAt');
    stage = 'ranking_index';
    await store.api(':runQuery', {structuredQuery: {from: [{collectionId: 'communityComments'}],
      where: {compositeFilter: {op: 'AND', filters: [
        {fieldFilter: {field: {fieldPath: 'contentKey'}, op: 'EQUAL', value: {stringValue: 'tvmaze:show:1'}}},
        {fieldFilter: {field: {fieldPath: 'status'}, op: 'EQUAL', value: {stringValue: 'approved'}}}]}},
      orderBy: [{field: {fieldPath: 'score'}, direction: 'DESCENDING'},
        {field: {fieldPath: 'createdAt'}, direction: 'DESCENDING'}], limit: 1}});
    stage = 'openai_moderation';
    const verdict = await service.classify({body: 'I enjoyed the story and the soundtrack.', authorName: 'Watchloom setup check'});
    if (verdict.status !== 'approved') throw new Error('Synthetic safety check was not approved');
    stage = 'health_write';
    await store.commit([store.set('communityAutomation/health', {project: PROJECT, policyVersion: POLICY, release: RELEASE,
      endpoint, model: verdict.model, verifiedAt: new Date()}, false)]);
    return {project: PROJECT, ready: true, policyVersion: POLICY, release: RELEASE};
  } catch (error) { return setupFailure(stage, error); }
}
