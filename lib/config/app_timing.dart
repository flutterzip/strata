/// Every deliberate wait in the app, in one place.
///
/// [Motion] owns how things move; this file owns how long the app makes
/// you **wait** — the splash, and the simulated network time behind sign
/// in, sign up, codes, PINs and pull-to-refresh. They are deliberate: an
/// action that completes in a single frame reads as broken, and a loading
/// state nobody ever sees cannot be judged. Swapping in a real backend makes
/// the network ones redundant: set them to zero, or delete the waits.
///
/// To tune the feel of the whole app, edit the numbers below. To speed
/// everything up at once (screenshots, automation), launch with
/// `--dart-define=timingScale=0` — every wait here is multiplied by it, and
/// at zero the splash is skipped entirely.
abstract final class AppTiming {
  /// Multiplier on every duration in this file. 1 = as designed.
  static final double scale =
      double.tryParse(const String.fromEnvironment('timingScale')) ?? 1.0;

  // ----------------------------------------------------------------- splash
  /// The choreographed intro: strata assemble, wordmark rises, tagline in.
  static const Duration splashIntro = Duration(milliseconds: 2100);

  /// How long the finished logo rests before leaving. Also the minimum the
  /// splash waits for the auth stage to load — it never leaves early.
  static const Duration splashHold = Duration(milliseconds: 350);

  /// The splash dissolving into the first screen.
  static const Duration splashExit = Duration(milliseconds: 750);

  /// Under reduce-motion the choreography is replaced by a still logo held
  /// this long, then a plain fade.
  static const Duration splashStill = Duration(milliseconds: 900);

  /// Upper bound on how long a test or a screenshot run has to wait for the
  /// splash to be completely gone.
  static Duration get splashTotal =>
      (splashIntro + splashHold + splashExit) * scale;

  // -------------------------------------------------- simulated network time
  static const Duration signIn = Duration(milliseconds: 1400);
  static const Duration signUp = Duration(milliseconds: 1700);

  /// Sign in / up with Apple or Google: the sheet a real provider shows
  /// takes about this long to hand back.
  static const Duration socialSignIn = Duration(milliseconds: 1500);

  static const Duration sendResetCode = Duration(milliseconds: 1200);
  static const Duration verifyCode = Duration(milliseconds: 1000);
  static const Duration resetPassword = Duration(milliseconds: 1200);
  static const Duration setPin = Duration(milliseconds: 900);
  static const Duration verifyPin = Duration(milliseconds: 650);

  /// Pull-to-refresh: the spinner stays at least this long, so a refresh
  /// that finishes instantly still reads as a refresh.
  static const Duration refresh = Duration(milliseconds: 900);

  /// Waits [designed] × [scale]. Use this instead of `Future.delayed` for
  /// any wait that exists for the sake of feel.
  static Future<void> wait(Duration designed) {
    final d = designed * scale;
    return d <= Duration.zero ? Future<void>.value() : Future<void>.delayed(d);
  }

  /// For `RefreshIndicator.onRefresh`: waits for [work] and at least
  /// [refresh], and never throws — a failed reload is shown by the screen's
  /// own error state, not by an exception out of the indicator.
  static Future<void> refreshing(Future<Object?> work) =>
      atLeast(refresh, work.then<void>((_) {}, onError: (Object _) {}));

  /// Runs [work] and resolves no sooner than [atLeast] × [scale], so a
  /// loading state never flashes for a single frame.
  static Future<T> atLeast<T>(Duration atLeast, Future<T> work) async {
    final results = await Future.wait<Object?>([work, wait(atLeast)]);
    return results.first as T;
  }
}
