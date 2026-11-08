import 'package:flutter/foundation.dart';

import '../services/media_ref.dart';
import '../shared/utils/money.dart';

/// What kind of movement a transaction is.
///
/// Carries its own label so no screen has to switch on the enum to print it,
/// and deliberately carries no colour or icon — those are theme and UI
/// concerns, and the seed data must stay theme-agnostic.
enum TxnKind {
  payment,
  transfer,
  refund,
  topUp,
  conversion;

  String get label => switch (this) {
        TxnKind.payment => 'Payment',
        TxnKind.transfer => 'Transfer',
        TxnKind.refund => 'Refund',
        TxnKind.topUp => 'Top-up',
        TxnKind.conversion => 'Conversion',
      };
}

/// One movement of money on one card.
///
/// [amountMinor] is **signed**: negative is money out, positive is money in.
/// Keeping the sign on the amount rather than in a separate `direction` flag
/// means a list can be summed directly and can never disagree with itself
/// about which way the money went.
@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.cardId,
    required this.kind,
    required this.merchant,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    this.note,
    this.receipt,
  });

  final String id;

  /// The card this moved on. Not a [PaymentCard]: a transaction outlives the
  /// card being removed from the wallet, and a stored object graph would
  /// duplicate every card into every record.
  final String cardId;

  final TxnKind kind;

  /// Who was paid, or what the movement was. Shown as the row's title.
  final String merchant;

  /// Free text, grouped on by the spending chart. Not an enum: a buyer
  /// renaming "Groceries" should not have to touch Dart.
  final String category;

  /// Signed, in the smallest currency unit. Negative is money out.
  final int amountMinor;

  final String currency;
  final DateTime occurredAt;

  /// The owner's own note. Editable; absent rather than empty when unset.
  final String? note;

  /// Optional photo of a receipt. A reference, never the bytes.
  final MediaRef? receipt;

  bool get isMoneyOut => amountMinor < 0;

  /// Signed for display: `-$4.75`, `+$99.00`.
  String get amountLabel => Money.signed(amountMinor, currency);

  /// Midnight on the day this happened, which is what the list groups by.
  DateTime get day =>
      DateTime(occurredAt.year, occurredAt.month, occurredAt.day);

  /// Spoken form. A screen reader announcing "minus four dollars" makes the
  /// listener do the arithmetic; "paid" and "received" say it outright.
  String get describedForAccessibility =>
      '$merchant, ${isMoneyOut ? 'paid' : 'received'} '
      '${Money.format(amountMinor.abs(), currency)}, $categoryLabel';

  /// Never blank, so a row and the chart agree on what an unset category is.
  String get categoryLabel =>
      category.trim().isEmpty ? 'Uncategorised' : category.trim();

  // ---------------------------------------------------------------- JSON
  //
  // Hand-written, like the rest of the models here, so the shape can be
  // changed without running build_runner. An unknown enum name falls back
  // rather than throwing: stored data outlives the code that wrote it, and
  // a rename must not brick the app on launch.

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        cardId: json['cardId'] as String? ?? '',
        kind: TxnKind.values.asNameMap()[json['kind'] as String? ?? ''] ??
            TxnKind.payment,
        merchant: json['merchant'] as String? ?? '',
        category: json['category'] as String? ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: (json['note'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['note'] as String).trim(),
        receipt: MediaRef.parse(json['receipt'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardId': cardId,
        'kind': kind.name,
        'merchant': merchant,
        'category': category,
        'amountMinor': amountMinor,
        'currency': currency,
        'occurredAt': occurredAt.toIso8601String(),
        'note': note,
        'receipt': receipt?.encoded,
      };

  /// Pass [clearNote] to remove a note: a null [note] means "unchanged",
  /// which cannot otherwise express "delete it".
  Transaction copyWith({
    String? cardId,
    TxnKind? kind,
    String? merchant,
    String? category,
    int? amountMinor,
    String? currency,
    DateTime? occurredAt,
    String? note,
    bool clearNote = false,
    MediaRef? receipt,
    bool clearReceipt = false,
  }) {
    final nextNote = clearNote
        ? null
        : note == null
            ? this.note
            : (note.trim().isEmpty ? null : note.trim());
    return Transaction(
      id: id,
      cardId: cardId ?? this.cardId,
      kind: kind ?? this.kind,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      note: nextNote,
      receipt: clearReceipt ? null : (receipt ?? this.receipt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.cardId == cardId &&
      other.kind == kind &&
      other.merchant == merchant &&
      other.category == category &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.occurredAt == occurredAt &&
      other.note == note &&
      other.receipt == receipt;

  @override
  int get hashCode => Object.hash(id, cardId, kind, merchant, category,
      amountMinor, currency, occurredAt, note, receipt);
}
