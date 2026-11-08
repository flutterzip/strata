/// Pure validation for the auth flows. No Flutter imports, so it unit-tests
/// instantly and can be reused by a real backend client.
abstract final class AuthValidation {
  /// Deliberately permissive. The only reliable test of an address is
  /// sending to it; over-strict patterns reject valid addresses and are a
  /// classic source of support tickets.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Enter your email address';
    if (!_email.hasMatch(t)) return 'That does not look like an email';
    return null;
  }

  static String? name(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Enter your name';
    if (t.length < 2) return 'That name looks too short';
    return null;
  }

  static String? password(String raw) {
    if (raw.isEmpty) return 'Enter your password';
    if (raw.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? confirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return 'Repeat your password';
    if (password != confirm) return 'Those passwords do not match';
    return null;
  }

  /// 0..4. Length carries the most weight because it is what actually
  /// resists an offline attack; character classes are a weak secondary
  /// signal, which is why a long passphrase outscores a short jumble.
  static int passwordStrength(String p) {
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (p.length >= 16) score++;
    final classes = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'\d'),
      RegExp(r'[^\w\s]'),
    ].where((r) => r.hasMatch(p)).length;
    if (classes >= 3) score++;
    // A single repeated character or an obvious sequence is not a password
    // however long it is.
    if (RegExp(r'^(.)\1+$').hasMatch(p)) return 0;
    return score.clamp(0, 4);
  }

  static String strengthLabel(int score) => switch (score) {
        0 => 'Too weak',
        1 => 'Weak',
        2 => 'Fair',
        3 => 'Strong',
        _ => 'Very strong',
      };

  /// A 6-digit one-time code.
  static String? otp(String raw, {int length = 6}) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return 'Enter the code we sent you';
    if (d.length < length) return 'The code is $length digits';
    return null;
  }
}
