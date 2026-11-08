import 'package:flutter/services.dart';

import '../../models/card_brand.dart';
import 'card_validation.dart';

/// Groups card digits as the user types, keeping the caret in the right place.
///
/// Regrouping is live because the network — and therefore the grouping —
/// changes mid-entry: American Express is 4-6-5, everything else 4-4-4-4.
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = CardValidation.digitsOnly(newValue.text);
    final brand = CardBrand.detect(digits);
    final capped = digits.length > brand.numberLength
        ? digits.substring(0, brand.numberLength)
        : digits;
    final formatted = CardValidation.format(capped, brand);

    // Preserve the caret by counting digits to its left, then re-finding that
    // many digits in the formatted string.
    final digitsBeforeCaret = CardValidation.digitsOnly(newValue.text.substring(
            0, newValue.selection.end.clamp(0, newValue.text.length)))
        .length;
    var caret = formatted.length;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == digitsBeforeCaret) {
        caret = i;
        break;
      }
      if (formatted.codeUnitAt(i) != 32) seen++;
    }

    return TextEditingValue(
      text: formatted,
      selection:
          TextSelection.collapsed(offset: caret.clamp(0, formatted.length)),
    );
  }
}

/// Formats MM/YY, inserting the slash automatically.
class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = CardValidation.digitsOnly(newValue.text);
    if (d.length > 4) d = d.substring(0, 4);

    // A leading digit above 1 can only be a single-digit month, so pad it.
    if (d.length == 1 && int.parse(d) > 1) d = '0$d';

    final out = d.length >= 3 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
