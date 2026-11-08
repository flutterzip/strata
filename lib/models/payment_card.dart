import 'package:flutter/foundation.dart';

import '../config/palette.dart';
import '../services/media_ref.dart';
import '../shared/utils/card_validation.dart';
import 'card_brand.dart';

enum CardFunding {
  debit,
  credit,
  virtualDebit;

  String get label => switch (this) {
        CardFunding.debit => 'Debit',
        CardFunding.credit => 'Credit',
        CardFunding.virtualDebit => 'Virtual debit',
      };
}

@immutable
class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.last4,
    required this.brand,
    required this.funding,
    required this.holder,
    required this.expiryMonth,
    required this.expiryYear,
    required this.skin,
    required this.balanceMinor,
    required this.currency,
    this.nickname,
    this.artwork,
    this.frozen = false,
    this.spendLimitMinor,
  });

  final String id;
  final String last4;
  final CardBrand brand;
  final CardFunding funding;
  final String holder;
  final int expiryMonth;
  final int expiryYear;
  final CardSkin skin;

  /// Balance in the smallest currency unit, avoiding floating-point money.
  final int balanceMinor;
  final String currency;

  /// What the owner calls this card — "Travel", "Household". Optional, and
  /// shown in place of the generic funding label when set.
  final String? nickname;

  /// Optional bundled or user-supplied artwork. When null the face is drawn
  /// procedurally from [skin].
  final MediaRef? artwork;

  /// Frozen cards cannot be spent from.
  ///
  /// A real state on the card rather than a flag held somewhere else: it has
  /// to survive a relaunch, show on the face, and be checked by every flow
  /// that moves money. Reversible by design — freezing a card you have
  /// mislaid is only useful if you can unfreeze it when it turns up.
  final bool frozen;

  /// Optional monthly spending cap, in minor units of [currency].
  ///
  /// Null means no cap. Compared against what has actually been spent on
  /// this card this month, which is derived from transactions rather than
  /// counted up separately — a second tally is a second thing to go wrong.
  final int? spendLimitMinor;

  bool get hasSpendLimit => spendLimitMinor != null && spendLimitMinor! > 0;

  String get expiryLabel =>
      '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}';

  /// Masked for display: never hold or show a full PAN after entry.
  String get maskedNumber => '•••• •••• •••• $last4';
  String get shortMask => '•••• $last4';

  /// What to print on the face and in lists.
  String get displayLabel =>
      (nickname?.trim().isNotEmpty ?? false) ? nickname!.trim() : funding.label;

  /// Spoken description. The nickname is only announced when there is one;
  /// otherwise [displayLabel] would repeat the funding type immediately
  /// before it ("Credit, Visa Credit, ending 4242").
  String get describedForAccessibility {
    final named =
        (nickname?.trim().isNotEmpty ?? false) ? '${nickname!.trim()}, ' : '';
    // Frozen comes first: it is the one thing that changes what you can do
    // with the card, and a screen reader user should not have to reach the
    // end of the sentence to find out.
    final state = frozen ? 'Frozen, ' : '';
    return '$state$named${brand.label} ${funding.label}, ending $last4, '
        'expires $expiryLabel';
  }

  // ---------------------------------------------------------------- JSON
  //
  // Hand-written rather than generated: a buyer can read this and change the
  // shape without running build_runner. Note what is NOT here — the full card
  // number and the security code are never serialised, because they must
  // never be persisted at all.

  factory PaymentCard.fromJson(Map<String, dynamic> json) => PaymentCard(
        id: json['id'] as String,
        last4: json['last4'] as String,
        brand: CardBrand.values.byName(json['brand'] as String? ?? 'unknown'),
        funding:
            CardFunding.values.byName(json['funding'] as String? ?? 'debit'),
        holder: json['holder'] as String? ?? '',
        expiryMonth: (json['expiryMonth'] as num?)?.toInt() ?? 1,
        expiryYear: (json['expiryYear'] as num?)?.toInt() ?? 2030,
        skin: CardSkin.values.byName(json['skin'] as String? ?? 'obsidian'),
        balanceMinor: (json['balanceMinor'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'USD',
        nickname: (json['nickname'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['nickname'] as String).trim(),
        artwork: MediaRef.parse(json['artwork'] as String?),
        frozen: json['frozen'] as bool? ?? false,
        spendLimitMinor: (json['spendLimitMinor'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'last4': last4,
        'brand': brand.name,
        'funding': funding.name,
        'holder': holder,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'skin': skin.name,
        'balanceMinor': balanceMinor,
        'currency': currency,
        'nickname': nickname,
        'artwork': artwork?.encoded,
        'frozen': frozen,
        'spendLimitMinor': spendLimitMinor,
      };

  /// Only the fields that can legitimately change are here. The number and
  /// security code are not stored at all — a different number is a different
  /// card, not an edit to this one. The currency is not here either: a card
  /// is denominated once, and changing it would silently reinterpret every
  /// amount already recorded against it.
  ///
  /// Pass an empty string to [nickname] to clear it.
  PaymentCard copyWith({
    CardSkin? skin,
    String? holder,
    String? nickname,
    int? expiryMonth,
    int? expiryYear,
    int? balanceMinor,
    bool? frozen,
    int? spendLimitMinor,
    bool clearSpendLimit = false,
  }) {
    final nextNickname = nickname == null
        ? this.nickname
        : (nickname.trim().isEmpty ? null : nickname.trim());
    return PaymentCard(
      id: id,
      last4: last4,
      brand: brand,
      funding: funding,
      holder: holder ?? this.holder,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      skin: skin ?? this.skin,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      currency: currency,
      nickname: nextNickname,
      artwork: artwork,
      frozen: frozen ?? this.frozen,
      // A null limit means "unchanged", so removing a cap needs its own
      // flag — the same reason `nickname` takes an empty string.
      spendLimitMinor:
          clearSpendLimit ? null : (spendLimitMinor ?? this.spendLimitMinor),
    );
  }

  /// Build from raw entry, keeping only what is safe to retain.
  factory PaymentCard.fromEntry({
    required String id,
    required String number,
    required String holder,
    required String expiry,
    required CardSkin skin,
    required CardFunding funding,
    String? nickname,
    int balanceMinor = 0,
    String currency = 'USD',
  }) {
    final d = CardValidation.digitsOnly(number);
    final e = CardValidation.digitsOnly(expiry);
    return PaymentCard(
      id: id,
      last4: d.length >= 4 ? d.substring(d.length - 4) : d,
      brand: CardBrand.detect(d),
      funding: funding,
      holder: holder.trim(),
      expiryMonth: e.length >= 2 ? int.parse(e.substring(0, 2)) : 1,
      expiryYear: e.length >= 4 ? 2000 + int.parse(e.substring(2, 4)) : 2030,
      skin: skin,
      balanceMinor: balanceMinor,
      currency: currency,
      nickname: (nickname?.trim().isEmpty ?? true) ? null : nickname!.trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentCard &&
      other.id == id &&
      other.skin == skin &&
      other.holder == holder &&
      other.nickname == nickname &&
      other.expiryMonth == expiryMonth &&
      other.expiryYear == expiryYear &&
      other.balanceMinor == balanceMinor &&
      other.frozen == frozen &&
      other.spendLimitMinor == spendLimitMinor;

  @override
  int get hashCode => Object.hash(id, skin, holder, nickname, expiryMonth,
      expiryYear, balanceMinor, frozen, spendLimitMinor);
}
