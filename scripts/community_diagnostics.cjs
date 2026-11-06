'use strict';
// Whitelisted diagnostic codes only. Provider messages/bodies can contain data.
const CODES = new Set(['invalid_api_key', 'insufficient_quota', 'rate_limit_exceeded',
  'model_not_found', 'insufficient_permissions', 'invalid_request_error',
  'billing_hard_limit_reached', 'organization_deactivated', 'unsupported_country_region_territory',
  'invalid_grant', 'invalid_client', 'invalid_scope', 'unauthorized_client', 'access_denied',
  'PERMISSION_DENIED', 'UNAUTHENTICATED', 'INVALID_ARGUMENT', 'NOT_FOUND',
  'FAILED_PRECONDITION', 'RESOURCE_EXHAUSTED', 'UNAVAILABLE', 'INTERNAL', 'DEADLINE_EXCEEDED',
  'SERVICE_DISABLED', 'IAM_PERMISSION_DENIED', 'ACCESS_TOKEN_SCOPE_INSUFFICIENT',
  'RATE_LIMIT_EXCEEDED', 'API_KEY_INVALID', 'USER_NOT_FOUND']);
function safeProviderCode(data) {
  const error = data?.error;
  const details = Array.isArray(error?.details) ? error.details : [];
  const reason = details.find(item => CODES.has(item?.reason))?.reason;
  if (error?.status === 'FAILED_PRECONDITION' && typeof error.message === 'string'
    && /index/i.test(error.message)) return 'INDEX_NOT_READY';
  for (const code of [reason, error?.code, error?.type, error?.status, error]) {
    if (CODES.has(code)) return code;
  }
  if (error?.message === 'USER_NOT_FOUND') return 'USER_NOT_FOUND';
  return 'UPSTREAM_ERROR';
}
function safeNetworkCode(error) {
  const allowed = new Set(['ENOTFOUND', 'EAI_AGAIN', 'ETIMEDOUT', 'ECONNRESET', 'ENETUNREACH', 'ECONNREFUSED', 'EPROTO', 'EPIPE',
    'UND_ERR_CONNECT_TIMEOUT', 'UND_ERR_SOCKET', 'UND_ERR_HEADERS_TIMEOUT', 'UND_ERR_BODY_TIMEOUT',
    'ECONNABORTED', 'EHOSTUNREACH', 'CERT_HAS_EXPIRED', 'CERT_NOT_YET_VALID',
    'DEPTH_ZERO_SELF_SIGNED_CERT', 'SELF_SIGNED_CERT_IN_CHAIN', 'UNABLE_TO_GET_ISSUER_CERT',
    'UNABLE_TO_GET_ISSUER_CERT_LOCALLY', 'UNABLE_TO_VERIFY_LEAF_SIGNATURE',
    'ERR_TLS_CERT_ALTNAME_INVALID', 'ERR_TLS_HANDSHAKE_TIMEOUT',
    'ERR_SSL_SSLV3_ALERT_HANDSHAKE_FAILURE', 'ERR_SSL_TLSV1_ALERT_INTERNAL_ERROR',
    'ERR_SSL_TLSV1_ALERT_PROTOCOL_VERSION', 'ERR_SSL_TLSV1_UNRECOGNIZED_NAME',
    'AbortError', 'TimeoutError']);
  const queue = [error];
  for (let i = 0; i < queue.length && i < 12; i++) {
    const value = queue[i];
    for (const code of [value?.code, value?.name]) if (allowed.has(code)) return code;
    if (value?.cause) queue.push(value.cause);
    if (Array.isArray(value?.errors)) queue.push(...value.errors.slice(0, 4));
    if (value?.message === 'unexpected redirect') return 'REDIRECT_REJECTED';
  }
  return 'NETWORK_ERROR';
}
// Only for the public, credential-free network probe. Never use for provider
// response bodies, comment text, or authenticated requests.
function publicNetworkDetails(error) {
  const clean = value => typeof value === 'string' ? value
    .replace(/(?:https?|socks[45]?):\/\/[^\s'"<>]+/gi, '[URL]')
    .replace(/\b(?:Bearer|Basic)\s+\S+/gi, '[AUTH REDACTED]')
    .replace(/\bsk-[A-Za-z0-9_-]{20,}/g, '[KEY REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[TOKEN REDACTED]')
    .replace(/[\u0000-\u001f\u007f]/g, ' ').slice(0, 240) : undefined;
  return {message: clean(error?.message), cause: clean(error?.cause?.message)};
}
module.exports = {safeProviderCode, safeNetworkCode, publicNetworkDetails};
