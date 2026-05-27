// lib/services/password_service.dart
//
// Three-person password system:
//   The settings password = SHA-256( person1Password + person2Password + person3Password )
//   All three parts must be present to authenticate.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordService {
  /// Hash the combined three-part password.
  static String hashCombinedPassword(
    String part1,
    String part2,
    String part3,
  ) {
    final combined = part1 + part2 + part3;
    final bytes = utf8.encode(combined);
    return sha256.convert(bytes).toString();
  }

  /// Verify three password parts against a stored hash.
  static bool verify(String part1, String part2, String part3, String storedHash) {
    if (storedHash.isEmpty) return false;
    final hash = hashCombinedPassword(part1, part2, part3);
    return hash == storedHash;
  }

  /// Returns true if a combined password string matches the stored hash.
  /// Used when all three parts are concatenated externally.
  static bool verifyRaw(String combined, String storedHash) {
    if (storedHash.isEmpty) return false;
    final bytes = utf8.encode(combined);
    final hash = sha256.convert(bytes).toString();
    return hash == storedHash;
  }
}
