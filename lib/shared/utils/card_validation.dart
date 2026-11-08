import '../../models/card_brand.dart';

/// Pure validation helpers. No Flutter imports, so they unit-test instantly.
abstract final class CardValidation {
  /// Strip every non-digit.
  static String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Luhn mod-10 checksum, the standard integrity check for card numbers.
  static bool luhn(String digits) {
    if (digits.length < 12) return false;
    var sum = 0;
    var double_ = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      final c = digits.codeUnitAt(i) - 48;
      if (c < 0 || c > 9) return false;
      var d = c;
      if (double_) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      double_ = !double_;
    }
    return sum % 10 == 0;
  }

  /// Group digits for display, e.g. "4242424242424242" -> "4242 4242 4242 4242".
  static String format(String digits, CardBrand brand) {
    final groups = brand.grouping;
    final out = StringBuffer();
    var i = 0;
    for (final g in groups) {
      if (i >= digits.length) break;
      if (i > 0) out.write(' ');
      out.write(digits.substring(i, (i + g).clamp(0, digits.length)));
      i += g;
    }
    if (i < digits.length) {
      out
        ..write(' ')
        ..write(digits.substring(i));
    }
    return out.toString();
  }

  /// `null` when valid, otherwise a user-facing reason.
  static String? number(String raw) {
    final d = digitsOnly(raw);
    if (d.isEmpty) return 'Enter your card number';
    final brand = CardBrand.detect(d);
    if (d.length < brand.numberLength) return 'That number looks too short';
    if (d.length > brand.numberLength) return 'That number looks too long';
    if (!luhn(d)) return 'Check the number and try again';
    return null;
  }

  /// Validates MM/YY and rejects anything already expired.
  static String? expiry(String raw, {DateTime? now}) {
    final d = digitsOnly(raw);
    if (d.isEmpty) return 'Enter the expiry date';
    if (d.length < 4) return 'Use MM/YY';
    final mm = int.parse(d.substring(0, 2));
    final yy = int.parse(d.substring(2, 4));
    if (mm < 1 || mm > 12) return 'That month does not exist';
    final today = now ?? DateTime.now();
    final year = 2000 + yy;
    // A card is valid through the final day of its expiry month.
    final endOfMonth = DateTime(year, mm + 1, 1);
    if (!endOfMonth.isAfter(today)) return 'That card has expired';
    return null;
  }

  static String? cvc(String raw, CardBrand brand) {
    final d = digitsOnly(raw);
    if (d.isEmpty) return 'Enter the security code';
    if (d.length != brand.cvcLength) {
      return 'The code is ${brand.cvcLength} digits';
    }
    return null;
  }

  static String? holder(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Enter the name on the card';
    if (t.length < 2) return 'That name looks too short';
    return null;
  }
}
