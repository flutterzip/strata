/// One slice of the spending summary.
///
/// Deliberately carries no colour. Colour is a theme concern: the chart is
/// drawn from [ChartRamp] by position, so light and dark mode can use
/// different values and the data stays theme-agnostic.
class SpendCategory {
  const SpendCategory({required this.label, required this.minor});

  final String label;

  /// Always positive: this is an amount spent, and the sign lives on the
  /// transactions it was derived from.
  final int minor;
}

/// The whole summary.
///
/// Not stored and not seeded — there is no `spending.json`. This is derived
/// from transactions by [SpendRollup], so the chart and the transaction list
/// can never disagree about what was spent.
class SpendSummary {
  const SpendSummary({
    required this.periodLabel,
    required this.currency,
    required this.categories,
  });

  final String periodLabel;
  final String currency;
  final List<SpendCategory> categories;

  int get totalMinor => categories.fold<int>(0, (sum, c) => sum + c.minor);
}
