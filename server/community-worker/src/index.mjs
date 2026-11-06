import {PROJECT, POLICY, RELEASE, commentId, trustedAuthor} from './policy.mjs';
import {ServiceError, account, limitedText, verifyToken} from './google.mjs';
import {ModerationService} from './moderation.mjs';
import {verifySetup} from './setup.mjs';

const response = (body, status = 200) => new Response(JSON.stringify(body), {status, headers: {
  'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'}});
function secretEquals(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || b.length < 40 || a.length !== b.length) return false;
  let different = 0; for (let i = 0; i < a.length; i++) different |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return different === 0;
}
export default {
  async fetch(request, env, context) {
    try {
      const url = new URL(request.url);
      if (request.method === 'GET' && url.pathname === '/health') return response({project: PROJECT, policyVersion: POLICY, release: RELEASE});
      if (request.method !== 'POST' || !['/v1/moderate', '/v1/verify-setup'].includes(url.pathname)) return response({error: 'not_found'}, 404);
      if (url.search || !request.headers.get('Content-Type')?.toLowerCase().startsWith('application/json')) throw new ServiceError('invalid_request', 400);
      const authorization = request.headers.get('Authorization') || '';
      if (!authorization.startsWith('Bearer ')) throw new ServiceError('unauthorized', 401);
      const token = authorization.slice(7);
      if (url.pathname === '/v1/verify-setup') {
        if (!secretEquals(token, env.SETUP_TOKEN)) throw new ServiceError('unauthorized', 401);
        await limitedText(request, 1024);
        const result = await verifySetup(env, url.origin + '/');
        return response(result, result.ready === true ? 200 : 503);
      }
      account(env);
      const viewer = await verifyToken(env, token);
      if (!trustedAuthor(viewer.user)) throw new ServiceError('verification_required', 403);
      let body; try { body = JSON.parse(await limitedText(request, 1024)); } catch (error) {
        if (error instanceof ServiceError) throw error;
        throw new ServiceError('invalid_request', 400);
      }
      if (!body || Object.keys(body).length !== 1 || !commentId(body.commentId)) throw new ServiceError('invalid_request', 400);
      const decision = new ModerationService(env).process(body.commentId, {viewerUid: viewer.uid});
      // Finish a claimed job even if the mobile request disconnects. The lease
      // and due timestamp still permit Cron recovery after an interrupted run.
      context?.waitUntil(decision.catch(() => {}));
      return response(await decision);
    } catch (error) {
      return response({error: error instanceof ServiceError ? error.code : 'service_unavailable'}, error instanceof ServiceError ? error.status : 503);
    }
  },
  async scheduled(_event, env, context) {
    const service = new ModerationService(env);
    const maintenance = Math.floor(Date.now() / 60000) % 10 === 0;
    context.waitUntil((maintenance ? service.maintain() : service.next()).catch(() => {
      // No request bodies, bearer tokens, identities or provider errors logged.
    }));
  },
};
