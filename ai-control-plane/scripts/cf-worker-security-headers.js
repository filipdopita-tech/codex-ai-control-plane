// OneFlow security headers Worker — Verizon DBIR 2026 + ADVANCED layer
// Author: Dopita / Claude (autonomous closure 2026-05-03)
// Deploy: curl -sS -X PUT \
//   "https://api.cloudflare.com/client/v4/accounts/4a6b6588a7ed0a2280ff7ee226da6e96/workers/scripts/oneflow-security-headers" \
//   -H "Authorization: Bearer $CF_API_TOKEN_WITH_WORKERS_SCOPE" \
//   -H "Content-Type: application/javascript+module" \
//   --data-binary @cf-worker-security-headers.js
//
// Bind route:
//   curl -sS -X POST \
//     "https://api.cloudflare.com/client/v4/zones/0d2103e71b04ffa1760783e4fd6877fc/workers/routes" \
//     -H "Authorization: Bearer $CF_API_TOKEN_WITH_WORKERS_SCOPE" \
//     -H "Content-Type: application/json" \
//     -d '{"pattern":"oneflow.cz/*","script":"oneflow-security-headers"}'

export default {
  async fetch(req, env, ctx) {
    const r = await fetch(req);
    const h = new Headers(r.headers);
    h.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
    h.set("X-Frame-Options", "DENY");
    h.set("X-Content-Type-Options", "nosniff");
    h.set("Referrer-Policy", "strict-origin-when-cross-origin");
    h.set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), interest-cohort=()");
    h.set(
      "Content-Security-Policy",
      "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://*.cloudflare.com https://static.cloudflareinsights.com; " +
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
        "img-src 'self' data: https:; " +
        "font-src 'self' https://fonts.gstatic.com; " +
        "connect-src 'self' https://*.cloudflare.com https://oneflow.cz; " +
        "frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
    );
    h.set("Cross-Origin-Opener-Policy", "same-origin");
    h.set("X-Powered-By", "OneFlow");
    return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h });
  },
};
