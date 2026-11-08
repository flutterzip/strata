import 'package:intl/intl.dart';

/// Currency formatting that keeps money in integer minor units.
abstract final class Money {
  static final Map<String, NumberFormat> _cache = {};

  /// The symbol alone, for a field prefix where the figure is being typed
  /// rather than displayed. Unknown currencies fall back to their code,
  /// which is correct and readable — inventing a glyph is not.
  static String symbol(String currency) => switch (currency) {
        'USD' => r'$',
        'EUR' => '€',
        'GBP' => '£',
        'NGN' => '₦',
        _ => currency,
      };

  static NumberFormat _fmt(String currency) => _cache.putIfAbsent(
        currency,
        () => NumberFormat.currency(
          symbol: switch (currency) {
            'USD' => r'$',
            'EUR' => '€',
            'GBP' => '£',
            'NGN' => '₦',
            _ => '$currency ',
          },
          decimalDigits: 2,
        ),
      );

  static String format(int minor, String currency) =>
      _fmt(currency).format(minor / 100);

  /// Signed for a ledger: `-$4.75` out, `+$99.00` in, `$0.00` for nothing.
  ///
  /// The sign goes outside the currency symbol. Letting [NumberFormat] do it
  /// produces `€-4.75`, which no bank statement has ever printed.
  static String signed(int minor, String currency) {
    if (minor == 0) return format(0, currency);
    final sign = minor < 0 ? '-' : '+';
    return '$sign${format(minor.abs(), currency)}';
  }

  /// Splits into major and minor parts so the UI can de-emphasise cents.
  static (String major, String minor) parts(int cents, String currency) {
    final full = format(cents, currency);
    final i = full.lastIndexOf('.');
    return i == -1 ? (full, '') : (full.substring(0, i), full.substring(i));
  }
}
