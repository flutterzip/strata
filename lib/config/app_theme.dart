import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'palette.dart';

/// Builds the light and dark themes from [Brand].
///
/// Both modes are generated from the same token names, so a surface can
/// never be styled for one mode and forgotten in the other.
abstract final class AppTheme {
  /// Bundled variable grotesque. One family, many weights and widths.
  static const String fontFamily = 'Bricolage';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? Brand.leafDark : Brand.leafInk,
      onPrimary: isDark ? Brand.paperDark : Colors.white,
      primaryContainer: isDark ? Brand.leafSoftDark : Brand.leafSoft,
      onPrimaryContainer: isDark ? Brand.leafDark : Brand.leafInk,
      secondary: isDark ? Brand.ink2Dark : Brand.ink2,
      onSecondary: isDark ? Brand.paperDark : Colors.white,
      secondaryContainer: isDark ? Brand.stoneSoftDark : Brand.stoneSoft,
      onSecondaryContainer: isDark ? Brand.inkDark : Brand.ink,
      tertiary: isDark ? Brand.leafDark : Brand.leaf,
      onTertiary: isDark ? Brand.paperDark : Colors.white,
      tertiaryContainer: isDark ? Brand.sandSoftDark : Brand.sandSoft,
      onTertiaryContainer: isDark ? Brand.inkDark : Brand.ink,
      // Ochre, not red: a neighbour of the accent rather than its opposite.
      // Every error state pairs this with an icon and words.
      error: isDark ? Brand.barkDark : Brand.bark,
      onError: isDark ? Brand.paperDark : Colors.white,
      errorContainer: isDark ? Brand.claySoftDark : Brand.claySoft,
      onErrorContainer: isDark ? Brand.barkDark : Brand.bark,
      surface: isDark ? Brand.paperDark : Brand.paper,
      onSurface: isDark ? Brand.inkDark : Brand.ink,
      surfaceContainerLowest: isDark ? Brand.paperDark : Brand.paper2,
      surfaceContainerLow: isDark ? Brand.paper2Dark : Brand.paper2,
      surfaceContainer: isDark ? Brand.cardDark : Brand.card,
      surfaceContainerHigh: isDark ? Brand.paper2Dark : Brand.paper2,
      surfaceContainerHighest: isDark ? Brand.cardDark : Brand.stoneSoft,
      onSurfaceVariant: isDark ? Brand.ink2Dark : Brand.ink2,
      outline: isDark ? Brand.ink3Dark : Brand.ink3,
      outlineVariant: Brand.line(isDark),
      inverseSurface: isDark ? Brand.paper : Brand.ink,
      onInverseSurface: isDark ? Brand.ink : Brand.paper,
      inversePrimary: isDark ? Brand.leafInk : Brand.leafDark,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final text = _typography(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brXl),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
          textStyle: text.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Hit.minSize,
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: Hit.minSize),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Brand.paper2Dark : Brand.card,
        contentPadding: Insets.field,
        border: _fieldBorder(scheme.outlineVariant),
        enabledBorder: _fieldBorder(scheme.outlineVariant),
        focusedBorder: _fieldBorder(scheme.primary, width: 1.6),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 1.6),
        labelStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodySmall?.copyWith(color: scheme.primary),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.outline),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brLg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: text.bodyMedium,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: Radii.brLg,
        borderSide: BorderSide(color: c, width: width),
      );

  /// Display sizes exploit the variable font's optical-size and width axes:
  /// large text is set narrower and tighter, which is how a grotesque is
  /// meant to behave at headline sizes.
  static List<FontVariation> _axes({
    required double opsz,
    required double wdth,
    required double wght,
  }) =>
      [
        FontVariation('opsz', opsz),
        FontVariation('wdth', wdth),
        FontVariation('wght', wght),
      ];

  static TextTheme _typography(ColorScheme s) {
    final on = s.onSurface;
    final soft = s.onSurfaceVariant;

    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 40,
        height: 1.06,
        letterSpacing: -0.6,
        color: on,
        fontWeight: FontWeight.w700,
        fontVariations: _axes(opsz: 96, wdth: 92, wght: 740),
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.1,
        letterSpacing: -0.45,
        color: on,
        fontWeight: FontWeight.w700,
        fontVariations: _axes(opsz: 72, wdth: 94, wght: 720),
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.14,
        letterSpacing: -0.35,
        color: on,
        fontWeight: FontWeight.w700,
        fontVariations: _axes(opsz: 48, wdth: 90, wght: 720),
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.18,
        letterSpacing: -0.4,
        color: on,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 36, wdth: 94, wght: 660),
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.24,
        letterSpacing: -0.25,
        color: on,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 24, wdth: 96, wght: 640),
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.3,
        letterSpacing: -0.15,
        color: on,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 18, wdth: 98, wght: 620),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.45,
        color: on,
        fontVariations: _axes(opsz: 16, wdth: 100, wght: 420),
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        color: on,
        fontVariations: _axes(opsz: 14, wdth: 100, wght: 420),
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.42,
        color: soft,
        fontVariations: _axes(opsz: 12, wdth: 100, wght: 440),
      ),
      labelLarge: TextStyle(
        fontSize: 15.5,
        letterSpacing: 0,
        color: on,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 16, wdth: 100, wght: 640),
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        color: soft,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 14, wdth: 100, wght: 600),
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.2,
        color: soft,
        fontWeight: FontWeight.w600,
        fontVariations: _axes(opsz: 12, wdth: 100, wght: 600),
      ),
    );
  }
}
