import 'package:flutter/foundation.dart';

/// The demo exchange-rate table, from `assets/data/rates.json`.
///
/// Static on purpose, and the UI says so with the date next to it. A screen
/// that presents a hardcoded table as a live rate is lying about something
/// people make decisions with.
@immutable
class RateTable {
  const RateTable({
    required this.asOf,
    required this.base,
    required this.feeBps,
    required this.rates,
  });

  /// The day these rates were recorded.
  final DateTime asOf;

  /// Currency every rate is quoted against.
  final String base;

  /// Fee in basis points, taken off the amount before conversion.
  /// 50 bps is 0.50%.
  final int feeBps;

  /// Units of each currency per one unit of [base].
  final Map<String, double> rates;

  bool supports(String currency) =>
      rates.containsKey(currency) && (rates[currency] ?? 0) > 0;

  /// Units of [to] per one unit of [from], or null when either is unknown.
  ///
  /// A cross rate, derived rather than stored: a table of every pair would
  /// be thirty entries for six currencies and could disagree with itself.
  double? rate(String from, String to) {
    if (from == to) return 1;
    if (!supports(from) || !supports(to)) return null;
    return rates[to]! / rates[from]!;
  }

  factory RateTable.fromJson(Map<String, dynamic> json) => RateTable(
        asOf: DateTime.tryParse(json['asOf'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        base: json['base'] as String? ?? 'USD',
        feeBps: (json['feeBps'] as num?)?.toInt() ?? 0,
        rates: {
          for (final e in (json['rates'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
      );
}
