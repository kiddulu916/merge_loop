// Pure request-validation for match-contacts. Kept in its own module so it can
// be unit-tested with `deno test` without importing index.ts (which calls
// Deno.serve at module load).

// Cap the hash list to bound enumeration attempts and payload size.
export const MAX_HASHES = 2000;
// SHA256 hex is 64 lowercase hex chars.
export const HASH_RE = /^[0-9a-f]{64}$/;

/** Result of validating an incoming hash payload. */
export type SanitizeResult =
  | { ok: false }
  | { ok: true; hashes: string[] };

/**
 * Validate/sanitize the request body's `hashes`. Enforces: non-empty array,
 * size cap, 64-hex format, de-duplication.
 */
export function sanitizeHashes(raw: unknown): SanitizeResult {
  if (!Array.isArray(raw) || raw.length === 0) return { ok: false };
  if (raw.length > MAX_HASHES) return { ok: false };
  const hashes = [
    ...new Set(
      raw.filter((h): h is string =>
        typeof h === "string" && HASH_RE.test(h)
      ),
    ),
  ];
  return { ok: true, hashes };
}
