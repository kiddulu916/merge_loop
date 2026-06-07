import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Pure, on-device normalization + hashing of contact identifiers.
///
/// PRIVACY: raw phone numbers and emails NEVER leave the device. The client
/// hashes them here and only the SHA256 hex digests are sent to the
/// `match-contacts` Edge Function. This class is intentionally dependency-free
/// and fully unit-tested so the normalization is byte-stable across devices —
/// if two devices normalize the same number differently, real friends won't
/// match.
///
/// Normalization rules:
///   - Email: trim + lowercase.
///   - Phone: reduce to digits and an optional leading `+`, then coerce toward
///     E.164. A `00` international prefix becomes `+`. A bare national number
///     (no `+`) is assumed to be [defaultCountryCode] (NANP `1` by default):
///     a 10-digit number is prefixed, an 11-digit number starting with the
///     country code is prefixed with `+`. The result is `+` followed by digits.
class ContactsHasher {
  const ContactsHasher._();

  /// Default country calling code used when a phone number has no `+`/`00`
  /// international prefix. NANP (`1`) by default.
  static const String defaultCountryCode = '1';

  /// True when [raw] looks like an email (contains `@`).
  static bool isEmail(String raw) => raw.contains('@');

  /// Normalize an email: trim surrounding whitespace and lowercase.
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  /// Normalize a phone number toward E.164 (`+` then digits only).
  ///
  /// Returns an empty string when there are no digits at all (caller should
  /// skip empty results).
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    final hasPlus = trimmed.startsWith('+');
    // Strip everything but digits.
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    if (hasPlus) {
      // Already international: keep as-is.
      return '+$digits';
    }
    // `00` international prefix → `+`.
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
      return digits.isEmpty ? '' : '+$digits';
    }
    // National number: assume the default country.
    if (digits.length == 10) {
      // e.g. 4155550100 → +14155550100
      return '+$defaultCountryCode$digits';
    }
    if (digits.length == 11 && digits.startsWith(defaultCountryCode)) {
      // e.g. 14155550100 → +14155550100
      return '+$digits';
    }
    // Fallback: best-effort, just prefix `+`. Stable across devices given the
    // same input, which is what matters for hashing equivalence.
    return '+$digits';
  }

  /// Normalize any contact identifier (email or phone).
  static String normalize(String raw) =>
      isEmail(raw) ? normalizeEmail(raw) : normalizePhone(raw);

  /// SHA256 (lowercase hex) of a raw identifier's normalized form. Returns null
  /// when the value normalizes to empty (nothing to hash).
  static String? hashContact(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) return null;
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// Hash a batch of raw identifiers, dropping empties and de-duplicating.
  static List<String> hashAll(Iterable<String> raws) {
    final out = <String>{};
    for (final raw in raws) {
      final h = hashContact(raw);
      if (h != null) out.add(h);
    }
    return out.toList();
  }
}
