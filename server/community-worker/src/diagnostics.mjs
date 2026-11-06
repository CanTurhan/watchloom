import {PROJECT, POLICY, RELEASE} from './policy.mjs';

export const SETUP_STAGES = Object.freeze(['server_credentials', 'google_oauth', 'firebase_auth',
  'pending_index', 'ranking_index', 'openai_moderation', 'health_write']);
const PROVIDER_CODES = new Set(['invalid_api_key', 'insufficient_quota', 'rate_limit_exceeded',
  'model_not_found', 'insufficient_permissions', 'invalid_request_error', 'invalid_grant',
  'invalid_client', 'invalid_scope', 'unauthorized_client', 'access_denied',
  'billing_hard_limit_reached', 'organization_deactivated', 'unsupported_country_region_territory',
  'PERMISSION_DENIED', 'UNAUTHENTICATED', 'INVALID_ARGUMENT', 'NOT_FOUND', 'FAILED_PRECONDITION',
  'RESOURCE_EXHAUSTED', 'UNAVAILABLE', 'INTERNAL', 'DEADLINE_EXCEEDED', 'SERVICE_DISABLED',
  'IAM_PERMISSION_DENIED', 'ACCESS_TOKEN_SCOPE_INSUFFICIENT', 'API_KEY_INVALID', 'USER_NOT_FOUND',
  'INDEX_NOT_READY', 'UPSTREAM_HTTP_ERROR']);
const LOCAL_CODES = new Set(['CHECK_FAILED', 'UPSTREAM_TIMEOUT', 'OUTBOUND_NETWORK_ERROR',
  'CRYPTO_KEY_INVALID', 'CRYPTO_OPERATION_FAILED', 'RUNTIME_UNSUPPORTED', 'UPSTREAM_INVALID_RESPONSE']);
const validStatus = status => Number.isInteger(status) && status >= 100 && status <= 599;

export function upstreamDiagnostic(data, status) {
  const error = data?.error, details = Array.isArray(error?.details) ? error.details : [];
  let code = 'UPSTREAM_HTTP_ERROR';
  if (error?.status === 'FAILED_PRECONDITION' && typeof error.message === 'string' && /index/i.test(error.message)) code = 'INDEX_NOT_READY';
  else {
    const candidates = [details.find(item => PROVIDER_CODES.has(item?.reason))?.reason,
      error?.code, error?.type, error?.status, error];
    code = candidates.find(value => PROVIDER_CODES.has(value)) || code;
    if (error?.message === 'USER_NOT_FOUND') code = 'USER_NOT_FOUND';
  }
  return {code, ...(validStatus(status) ? {status} : {})};
}
export function setupFailure(stage, error) {
  let code = PROVIDER_CODES.has(error?.upstreamCode) ? error.upstreamCode : 'CHECK_FAILED';
  if (code === 'CHECK_FAILED') {
    code = new Map([['TimeoutError', 'UPSTREAM_TIMEOUT'], ['AbortError', 'UPSTREAM_TIMEOUT'],
      ['TypeError', 'OUTBOUND_NETWORK_ERROR'], ['DataError', 'CRYPTO_KEY_INVALID'],
      ['OperationError', 'CRYPTO_OPERATION_FAILED'], ['NotSupportedError', 'RUNTIME_UNSUPPORTED'],
      ['SyntaxError', 'UPSTREAM_INVALID_RESPONSE']]).get(error?.name) || code;
  }
  return {error: 'setup_check_failed', ready: false, project: PROJECT, policyVersion: POLICY, release: RELEASE,
    stage: SETUP_STAGES.includes(stage) ? stage : 'server_credentials', code,
    ...(validStatus(error?.upstreamStatus) ? {upstreamStatus: error.upstreamStatus} : {})};
}
// Used on the owner's side as well: never copy arbitrary remote strings, names,
// messages, URLs, response bodies or identifiers into Terminal output.
export function readSetupFailure(data) {
  if (data?.error !== 'setup_check_failed' || data.ready !== false || data.project !== PROJECT
    || data.policyVersion !== POLICY || data.release !== RELEASE || !SETUP_STAGES.includes(data.stage)
    || (!PROVIDER_CODES.has(data.code) && !LOCAL_CODES.has(data.code))) return null;
  return {stage: data.stage, code: data.code,
    ...(validStatus(data.upstreamStatus) ? {upstreamStatus: data.upstreamStatus} : {})};
}
