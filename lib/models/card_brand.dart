/// Card network, derived from the issuer identification number (IIN).
///
/// Strata renders each network as its plain name plus an original geometric
/// mark drawn in code. It does not reproduce any network's trademarked logo.
enum CardBrand {
  visa('Visa', 'Visa', 16, 3),
  mastercard('Mastercard', 'Mastercard', 16, 3),
  amex('American Express', 'Amex', 15, 4),
  discover('Discover', 'Discover', 16, 3),
  jcb('JCB', 'JCB', 16, 3),
  unknown('Card', 'Card', 16, 3);

  const CardBrand(this.label, this.short, this.numberLength, this.cvcLength);

  /// Full display name, for prose and detail rows.
  final String label;

  /// Abbreviated name for tight spaces such as the card face, where
  /// "American Express" does not fit beside the other fields.
  final String short;

  /// Digits in a well-formed number for this network.
  final int numberLength;

  /// Digits in the security code.
  final int cvcLength;

  bool get isKnown => this != CardBrand.unknown;

  /// How the digits group visually, e.g. 4-4-4-4 or Amex's 4-6-5.
  List<int> get grouping => switch (this) {
        CardBrand.amex => const [4, 6, 5],
        _ => const [4, 4, 4, 4],
      };

  /// Resolve a network from the leading digits of [digits].
  ///
  /// Ranges follow the published IIN allocations. Partial input resolves as
  /// soon as it is unambiguous, which is what lets the UI reveal the network
  /// while the user is still typing.
  static CardBrand detect(String digits) {
    if (digits.isEmpty) return CardBrand.unknown;
    int head(int n) =>
        digits.length < n ? -1 : int.parse(digits.substring(0, n));

    if (digits[0] == '4') return CardBrand.visa;

    final h2 = head(2);
    if (h2 == 34 || h2 == 37) return CardBrand.amex;
    if (h2 >= 51 && h2 <= 55) return CardBrand.mastercard;
    if (h2 == 35) return CardBrand.jcb;
    if (h2 == 65) return CardBrand.discover;

    final h4 = head(4);
    if (h4 >= 2221 && h4 <= 2720) return CardBrand.mastercard;
    if (h4 == 6011) return CardBrand.discover;

    final h6 = head(6);
    if (h6 >= 622126 && h6 <= 622925) return CardBrand.discover;

    return CardBrand.unknown;
  }
}
