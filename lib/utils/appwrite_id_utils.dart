import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:crypto/crypto.dart';

/// Ensures every rowId and fileId passed to Appwrite 1.8 TablesDB / Storage
/// satisfies Appwrite's strict UID rules:
/// - At most 36 characters
/// - Only `a-z`, `A-Z`, `0-9`, and `_`
/// - Cannot start with a leading underscore `_`
class AppwriteIdUtils {
  AppwriteIdUtils._();

  static final RegExp _validUidPattern =
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{0,35}$');

  static bool isValidUid(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return _validUidPattern.hasMatch(raw);
  }

  /// Generates a fresh Appwrite-compatible unique ID.
  static String uniqueId() => ID.unique();

  /// Converts any string (UUID with hyphens, composite key > 36 chars,
  /// date string `YYYY-MM-DD`, etc.) into a deterministic valid Appwrite UID.
  static String toValidUid(String? raw, {String prefix = 'r'}) {
    if (raw == null || raw.trim().isEmpty) return ID.unique();
    final trimmed = raw.trim();
    if (_validUidPattern.hasMatch(trimmed)) return trimmed;

    final normalized = trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+'), '');
    if (normalized.isNotEmpty &&
        normalized.length <= 36 &&
        _validUidPattern.hasMatch(normalized)) {
      return normalized;
    }

    final cleanPrefix =
        prefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isEmpty ? 'r' : prefix;
    final p = cleanPrefix.substring(0, 1);
    final hash = sha1.convert(utf8.encode(trimmed)).toString();
    return '${p}_${hash.substring(0, 34)}';
  }
}

