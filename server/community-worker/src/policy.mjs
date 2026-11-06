export const PROJECT = 'watchloom-canturhan';
export const POLICY = '2026-11-06-auto-v1';
export const RELEASE = 'automatic-community-v1';
export const commentId = value => typeof value === 'string' && /^[A-Za-z0-9]{20}$/.test(value);
export const uidValid = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
export function endpointValid(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && /^[a-z0-9-]+\.[a-z0-9-]+\.workers\.dev$/.test(url.hostname)
      && !url.username && !url.password && !url.port && url.pathname === '/' && !url.search && !url.hash;
  } catch { return false; }
}
export function ready(config) {
  return config?.enabled === true && config.moderationReady === true && config.rulesVersion === 2
    && config.moderationMode === 'automatic' && config.acceptedPolicyVersion === POLICY
    && endpointValid(config.moderationEndpoint);
}
export function trustedAuthor(account) {
  return !!account && !account.disabled && (account.emailVerified === true
    || account.providerUserInfo?.some(p => ['apple.com', 'google.com'].includes(p.providerId)) === true);
}
export function fold(value) {
  return value.normalize('NFKC').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '')
    .replaceAll('ı', 'i').replaceAll('0', 'o').replaceAll('1', 'i').replaceAll('3', 'e')
    .replaceAll('4', 'a').replaceAll('5', 's').replaceAll('7', 't');
}
const taboo = /(^|[^a-z])(fuck(?:ing|er|ers)?|shit(?:ty)?|bitch(?:es)?|nigger|nigga|cunt|orospu(?:cocugu)?|siktir(?:git)?|sikik|sikeyim|siktim|sikerim|amk|aq|yarrak|ibne)([^a-z]|$)/;
export function localReason(data) {
  if (!data || data.schema !== 1 || data.policyVersion !== POLICY || data.contentKind !== 'series'
    || !/^tvmaze:show:[1-9][0-9]{0,9}$/.test(data.contentKey || '') || !uidValid(data.authorUid)
    || typeof data.isSpoiler !== 'boolean' || !(data.createdAt instanceof Date)
    || (data.parentId !== null && !commentId(data.parentId))) return 'invalidContent';
  if (typeof data.authorName !== 'string' || !(/^@[a-z][a-z0-9_]{2,19}$/.test(data.authorName)
    || /^[\p{L}\p{M}\p{N} _-]{3,24}$/u.test(data.authorName))) return 'invalidIdentity';
  if (typeof data.body !== 'string' || data.body.trim().length < 1 || data.body.length > 1200
    || !/^[\p{L}\p{M}\p{N}\p{P}\p{S} \n]+$/u.test(data.body)) return 'invalidContent';
  for (const text of [data.body, data.authorName.replace(/^@/, '')]) {
    const normalized = fold(text);
    if (/(^|[^\p{L}])piç([^\p{L}]|$)/iu.test(text)) return 'abuse';
    if (taboo.test(normalized) || taboo.test(normalized.replace(/[\s._*-]/g, ''))) return 'abuse';
    if (/(seni|sizi|hepinizi)\s+(oldur|keser|vurur|yakar)/.test(normalized)) return 'violence';
  }
  if (/(https?\s*:|www\s*\.|@)/i.test(data.body) || /(?:\+?\d[ ()-]*){10,}/.test(data.body)) return 'personalInformation';
  return null;
}
export function moderationVerdict(json, expected = 2) {
  if (!json || typeof json.model !== 'string' || !json.model.length || json.model.length > 160 || !Array.isArray(json.results)
    || json.results.length !== expected) throw new Error('invalid_moderation_response');
  let reason = null;
  for (const result of json.results) {
    if (typeof result.flagged !== 'boolean' || !result.categories || !result.category_scores
      || !['hate', 'harassment', 'violence', 'sexual', 'self-harm'].every(k =>
        typeof result.categories[k] === 'boolean' && Number.isFinite(result.category_scores[k])
        && result.category_scores[k] >= 0 && result.category_scores[k] <= 1)
      || !Object.values(result.categories).every(v => typeof v === 'boolean')
      || !Object.values(result.category_scores).every(v => Number.isFinite(v) && v >= 0 && v <= 1)) {
      throw new Error('invalid_moderation_response');
    }
    const flags = Object.entries(result.categories).filter(([, flag]) => flag).map(([key]) => key);
    if (result.flagged || flags.length) {
      reason = flags.some(k => k.startsWith('violence') || k.endsWith('/threatening')) ? 'violence'
        : flags.some(k => k.startsWith('hate')) ? 'hate'
        : flags.some(k => k.startsWith('sexual')) ? 'sexual'
        : flags.some(k => k.startsWith('self-harm')) ? 'selfHarm' : 'abuse';
    }
  }
  return {status: reason ? 'rejected' : 'approved', reason, model: json.model};
}
