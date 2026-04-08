/**
 * Filters out expected console errors from E2E test runs.
 *
 * These are not app bugs — they come from:
 * - External IPTV stream URLs that are expired/unavailable
 * - CORS blocks on external image/logo CDNs
 * - Browser autoplay policy restrictions
 * - WebSocket reconnection attempts
 * - Network errors from external resources
 */
const KNOWN_ERROR_PATTERNS = [
  // Backend / WebSocket connectivity
  "ERR_CONNECTION_REFUSED",
  "WebSocket",

  // HLS media player errors (stream URLs may be expired/invalid)
  "WebHlsVideo",
  "403 (Forbidden)",
  "autoplay",
  "play() request was interrupted",

  // External resource loading (channel logos, VOD posters)
  "CORS policy",
  "Access-Control-Allow-Origin",
  "net::ERR_FAILED",
  "net::ERR_",
  "502 (Bad Gateway)",
  "504 (Gateway",
  "Failed to load resource",

  // Browser/Flutter internals
  "favicon",
  "manifest.json",
  "service-worker",
  "FontManifest",
  "cupertino",
];

/**
 * Returns only genuine app errors from a collected error list.
 *
 * Usage:
 *   const appErrors = filterAppErrors(collectedErrors);
 *   expect(appErrors).toHaveLength(0);
 */
export function filterAppErrors(errors: string[]): string[] {
  return errors.filter(
    (e) => !KNOWN_ERROR_PATTERNS.some((pattern) => e.includes(pattern)),
  );
}
