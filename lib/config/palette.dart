import 'package:flutter/material.dart';

/// Strata's colour system.
///
/// Built as **paper and ink with a single accent**, not as a set of competing
/// hues. Three rules hold everywhere:
///
/// 1. **One saturated colour.** [leaf] is the only chromatic accent in the
///    app. Nothing else competes with it for attention.
/// 2. **Everything else is a wash.** The tint family below sits at very high
///    lightness and very low chroma, so the tints read as tinted paper rather
///    than as colours. Pale washes never clash the way two saturated hues do.
/// 3. **Ink is never black, paper is never white.** Both carry a faint green
///    cast from the accent, which is what makes a palette feel composed
///    rather than assembled.
///
/// There is deliberately no second accent. If something needs to stand out
/// next to [leaf], change its weight, size or surface — not its hue.
abstract final class Brand {
  // ------------------------------------------------------------ light mode
  /// App background: warm off-white with a green-grey cast.
  static const Color paper = Color(0xFFF4F3EE);

  /// Recessed surface, one step down from [paper].
  static const Color paper2 = Color(0xFFEAE9E1);

  /// Raised surface. The only true white in the system.
  static const Color card = Color(0xFFFFFFFF);

  /// Primary text: a deep warm near-black, green-cast, never #000.
  static const Color ink = Color(0xFF1B2019);

  /// Secondary text.
  static const Color ink2 = Color(0xFF585F54);

  /// Tertiary text and disabled states.
  static const Color ink3 = Color(0xFF8B9187);

  // ------------------------------------------------------------- dark mode
  static const Color paperDark = Color(0xFF121511);
  static const Color paper2Dark = Color(0xFF1A1E18);
  static const Color cardDark = Color(0xFF20251E);
  static const Color inkDark = Color(0xFFECEFE9);
  static const Color ink2Dark = Color(0xFFA8AFA4);
  static const Color ink3Dark = Color(0xFF777E73);

  // ---------------------------------------------------------- the accent
  /// The single saturated colour in the app.
  static const Color leaf = Color(0xFF2E6B4C);

  /// Darkened for text and icons on light surfaces, where [leaf] alone is
  /// short of a comfortable contrast ratio.
  static const Color leafInk = Color(0xFF245539);

  /// Lightened for dark surfaces, where [leaf] is too dim to read.
  static const Color leafDark = Color(0xFF7FD3A4);

  // ------------------------------------------------------------ the washes
  // Pale, low-chroma tints. Backgrounds only — never text, never borders.
  static const Color leafSoft = Color(0xFFDCEBE0);
  static const Color sandSoft = Color(0xFFF3ECDC);
  static const Color stoneSoft = Color(0xFFE8E8E2);
  static const Color claySoft = Color(0xFFF1E4D9);

  /// A mid sage used for the second ambient mass on dark backgrounds, where
  /// the pale washes disappear entirely.
  static const Color sageMass = Color(0xFF3E5E49);

  static const Color leafSoftDark = Color(0xFF16311F);
  static const Color sandSoftDark = Color(0xFF332C19);
  static const Color stoneSoftDark = Color(0xFF26281F);
  static const Color claySoftDark = Color(0xFF33251C);

  // ---------------------------------------------------------- notification
  /// Errors use a deep ochre — a neighbour of the accent by way of
  /// yellow-green, not its opposite. Colour never carries the meaning on its
  /// own: every error state also has an icon and words.
  static const Color bark = Color(0xFF7E5A24);
  static const Color barkDark = Color(0xFFD9A84E);

  static Color line(bool isDark) => isDark
      ? const Color(0xFFECEFE9).withValues(alpha: 0.12)
      : const Color(0xFF1B2019).withValues(alpha: 0.12);
}

/// The finish of a card face. Named for natural materials, all within the
/// one hue family so no two cards ever clash side by side in the carousel.
enum CardSkin {
  forest('Forest', Color(0xFF1E3A2B), Color(0xFF0C1811), Color(0xFF4E7D63)),
  moss('Moss', Color(0xFF2E6B4C), Color(0xFF16402C), Color(0xFF7FD3A4)),
  sage('Sage', Color(0xFF6E8C72), Color(0xFF445C49), Color(0xFFBFD4C2)),
  stone('Stone', Color(0xFF2A2E28), Color(0xFF131612), Color(0xFF5E655B)),
  bone('Bone', Color(0xFFEDEAE0), Color(0xFFCFCBBD), Color(0xFFFFFFFF));

  const CardSkin(this.label, this.base, this.shade, this.highlight);

  final String label;
  final Color base;
  final Color shade;
  final Color highlight;

  /// True when the face is light enough to need dark text.
  bool get isLight => this == CardSkin.bone;

  Color get onFace => isLight ? Brand.ink : Colors.white;

  Gradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, shade],
      );
}

/// Sequential ramp for the spending chart.
///
/// One hue stepped through lightness, which is the correct encoding for
/// parts of a single whole — categorical hues would imply the segments are
/// different kinds of thing, and would reintroduce clashing colour.
abstract final class ChartRamp {
  static const List<Color> light = [
    Color(0xFF15402B),
    Color(0xFF216244),
    Color(0xFF2E8459),
    Color(0xFF5AA882),
    Color(0xFF96C9AE),
  ];

  static const List<Color> dark = [
    Color(0xFF9FDCBA),
    Color(0xFF6FC096),
    Color(0xFF479E74),
    Color(0xFF2E7554),
    Color(0xFF1E4E39),
  ];

  static Color at(int index, bool isDark) {
    final ramp = isDark ? dark : light;
    return ramp[index % ramp.length];
  }
}
