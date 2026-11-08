import 'package:flutter/foundation.dart';

import 'transaction.dart';

/// One dimension of [TxnFilter], so a chip knows which facet it clears.
enum TxnFacet { card, category, dates, query }

/// What the transaction list is currently narrowed to.
///
/// Immutable and self-matching: the screen holds one of these and every
/// other derived value — the visible rows, the chip row, the empty state —
/// reads from it, so there is no second place for the filter to disagree
/// with what is on screen.
@immutable
class TxnFilter {
  const TxnFilter({
    this.cardId,
    this.category,
    this.from,
    this.to,
    this.query = '',
  });

  /// Nothing narrowed.
  static const TxnFilter none = TxnFilter();

  final String? cardId;
  final String? category;

  /// Inclusive day bounds. [to] covers its whole day — an exclusive upper
  /// bound silently hides everything after midnight on the day the user
  /// picked, which looks like data loss.
  final DateTime? from;
  final DateTime? to;

  /// Merchant search. Trimmed and case-folded at match time.
  final String query;

  bool get hasDates => from != null || to != null;
  bool get hasQuery => query.trim().isNotEmpty;

  bool get isActive =>
      cardId != null || category != null || hasDates || hasQuery;

  /// Facets in play, for the count on the filter button. A date range is one
  /// facet however many ends it has.
  int get activeCount =>
      (cardId != null ? 1 : 0) +
      (category != null ? 1 : 0) +
      (hasDates ? 1 : 0) +
      (hasQuery ? 1 : 0);

  bool matches(Transaction t) {
    if (cardId != null && t.cardId != cardId) return false;
    if (category != null && t.categoryLabel != category) return false;
    if (from != null) {
      final start = DateTime(from!.year, from!.month, from!.day);
      if (t.occurredAt.isBefore(start)) return false;
    }
    if (to != null) {
      // End of the chosen day, not its start.
      final end = DateTime(to!.year, to!.month, to!.day, 23, 59, 59, 999);
      if (t.occurredAt.isAfter(end)) return false;
    }
    if (hasQuery &&
        !t.merchant.toLowerCase().contains(query.trim().toLowerCase())) {
      return false;
    }
    return true;
  }

  TxnFilter copyWith({
    String? cardId,
    String? category,
    DateTime? from,
    DateTime? to,
    String? query,
  }) =>
      TxnFilter(
        cardId: cardId ?? this.cardId,
        category: category ?? this.category,
        from: from ?? this.from,
        to: to ?? this.to,
        query: query ?? this.query,
      );

  /// Drop one facet. [copyWith] cannot express this, because a null argument
  /// there means "leave it alone".
  TxnFilter cleared(TxnFacet facet) => TxnFilter(
        cardId: facet == TxnFacet.card ? null : cardId,
        category: facet == TxnFacet.category ? null : category,
        from: facet == TxnFacet.dates ? null : from,
        to: facet == TxnFacet.dates ? null : to,
        query: facet == TxnFacet.query ? '' : query,
      );

  @override
  bool operator ==(Object other) =>
      other is TxnFilter &&
      other.cardId == cardId &&
      other.category == category &&
      other.from == from &&
      other.to == to &&
      other.query == query;

  @override
  int get hashCode => Object.hash(cardId, category, from, to, query);
}
