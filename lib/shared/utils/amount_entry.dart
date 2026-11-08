import 'package:flutter/foundation.dart';

import 'money.dart';

/// An amount being typed on a numeric keypad.
///
/// Digits are minor units, and there is no decimal point — typing 4, 2, 5, 0
/// means 42.50. That is how every card terminal behaves, it removes a key
/// that is easy to hit twice, and it makes a malformed amount impossible to
/// express rather than something to validate.
@immutable
class AmountEntry {
  const AmountEntry(this.digits);

  static const AmountEntry empty = AmountEntry('');

  /// Nine digits is a little under ten million major units — past anything a
  /// person means to type, and well inside a safe integer.
  static const int maxDigits = 9;

  /// The raw digits typed, most significant first. Never holds a leading
  /// zero, so there is one representation of every amount.
  final String digits;

  bool get isEmpty => digits.isEmpty;

  int get minor => digits.isEmpty ? 0 : int.parse(digits);

  String formatted(String currency) => Money.format(minor, currency);

  AmountEntry push(String digit) {
    // A keypad should only ever send digits, but an ignored keystroke is a
    // better failure than a FormatException from int.parse later.
    if (digit.length != 1 ||
        digit.codeUnitAt(0) < 0x30 ||
        digit.codeUnitAt(0) > 0x39) {
      return this;
    }
    if (digits.isEmpty && digit == '0') return this;
    if (digits.length >= maxDigits) return this;
    return AmountEntry(digits + digit);
  }

  AmountEntry backspace() => digits.isEmpty
      ? this
      : AmountEntry(digits.substring(0, digits.length - 1));

  /// Load an existing amount back for editing.
  static AmountEntry fromMinor(int minor) =>
      minor <= 0 ? empty : AmountEntry(minor.toString());

  @override
  bool operator ==(Object other) =>
      other is AmountEntry && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
