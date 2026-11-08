/// The product's identity, in one place.
///
/// Renaming the app is a single edit here. Copy in `assets/data/*.json` uses
/// the `{app}` placeholder rather than spelling the name out, so seed text
/// follows the rename too — see [fill].
abstract final class AppBrand {
  static const String name = 'Strata';

  /// Shown under the wordmark where there is room for it.
  static const String tagline = 'Every card, one balance.';

  /// Reverse-DNS id, matching the bundle identifier.
  static const String id = 'dev.strata.strata';

  /// Replace `{app}` in seed copy with the product name.
  static String fill(String copy) => copy.replaceAll('{app}', name);
}
