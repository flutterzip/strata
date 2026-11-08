import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/config/app_timing.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/providers/recipient_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/services/recipient_repository.dart';
import 'package:strata/services/transaction_repository.dart';
import 'package:strata/services/wallet_repository.dart';
import 'package:strata/shared/widgets/card_face.dart';

const sampleCard = PaymentCard(
  id: 'c_test',
  last4: '4242',
  brand: CardBrand.visa,
  funding: CardFunding.credit,
  holder: 'ADA LOVELACE',
  expiryMonth: 12,
  expiryYear: 2034,
  skin: CardSkin.moss,
  balanceMinor: 125000,
  currency: 'USD',
);

/// Another card, for the screens whose whole point is holding several.
///
/// [sampleCard.copyWith] cannot do this: `id` is identity and is deliberately
/// not copyable, so a second card has to be built rather than cloned.
PaymentCard cardNamed(
  String id, {
  required String nickname,
  required String last4,
  int balanceMinor = 125000,
  String currency = 'USD',
  CardSkin skin = CardSkin.moss,
  bool frozen = false,
}) =>
    PaymentCard(
      id: id,
      last4: last4,
      brand: CardBrand.visa,
      funding: CardFunding.credit,
      holder: 'ADA LOVELACE',
      expiryMonth: 12,
      expiryYear: 2034,
      skin: skin,
      balanceMinor: balanceMinor,
      currency: currency,
      nickname: nickname,
      frozen: frozen,
    );

/// Transaction repository that always fails, for the error branch.
class FailingTransactionRepository implements TransactionRepository {
  @override
  Future<List<Transaction>> load() async => throw Exception('offline');
  @override
  Future<Transaction> add(Transaction txn) async => throw Exception('offline');
  @override
  Future<Transaction> update(
          String id, Transaction Function(Transaction) change) async =>
      throw Exception('offline');
  @override
  Future<void> remove(String id) async => throw Exception('offline');
}

/// Repository that always fails, for exercising the error branch.
class FailingWalletRepository implements WalletRepository {
  @override
  Future<List<PaymentCard>> load() async => throw Exception('offline');
  @override
  Future<PaymentCard> add(PaymentCard card) async => throw Exception('offline');
  @override
  Future<void> remove(String id) async => throw Exception('offline');
  @override
  Future<PaymentCard> restyle(String id, CardSkin skin) async =>
      throw Exception('offline');
  @override
  Future<PaymentCard> update(
          String id, PaymentCard Function(PaymentCard) change) async =>
      throw Exception('offline');
}

/// Wraps [child] in the providers and theme the app supplies at runtime.
Widget harness(
  Widget child, {
  List<PaymentCard>? cards,
  WalletRepository? repository,
  List<Transaction>? transactions,
  TransactionRepository? txnRepository,
  List<Recipient>? recipients,
  RecipientRepository? recipientRepository,
  bool reduceMotion = false,
  bool dark = false,
  Size size = const Size(420, 900),
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(
        repository ?? InMemoryWalletRepository(seed: cards ?? [sampleCard]),
      ),
      // Always overridden, never left to the real store: an asset-seeded
      // repository makes the second test in a file hang on a bundle load
      // that never completes.
      transactionRepositoryProvider.overrideWithValue(
        txnRepository ??
            InMemoryTransactionRepository(seed: transactions ?? const []),
      ),
      recipientRepositoryProvider.overrideWithValue(
        recipientRepository ??
            InMemoryRecipientRepository(seed: recipients ?? const []),
      ),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: child,
      ),
    ),
  );
}

/// Taps a card in the wallet stack by its visible sliver.
///
/// `tester.tap` aims at the centre of a widget, and in a shut stack a card's
/// centre is behind the card stacked over it — so the tap lands on the wrong
/// card, or on the add strip, and nothing warns you. The sliver is the only
/// part of a shut card anyone can actually hit.
Future<void> tapCardSliver(WidgetTester tester, int index) async {
  final rect = tester.getRect(find.byType(CardFace).at(index));
  await tester.tapAt(Offset(rect.center.dx, rect.top + 20));
  await tester.pumpAndSettle();
}

/// Pumps a whole-app test past the splash, in frames rather than one jump,
/// so the splash's timeline, its awaited futures and the first screen's
/// entrance all actually run. `pumpAndSettle` is out: the app has ambient
/// animations that never settle.
Future<void> pumpPastSplash(WidgetTester tester) async {
  final end = AppTiming.splashTotal + const Duration(milliseconds: 1200);
  const frame = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < end; t += frame) {
    await tester.pump(frame);
  }
}

/// Sizes the test surface like a phone. The default 800x600 is a landscape
/// tablet shape that no user of this app will ever see.
void usePhoneSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// True when any node in the live semantics tree carries [label].
///
/// `find.bySemanticsLabel` resolves against the render object that *owns* a
/// node, which misses labels that sit above merged or excluded subtrees.
/// Walking the tree asserts what a screen reader would actually announce.
bool hasSemanticsLabel(WidgetTester tester, String label) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;
  var found = false;
  void walk(SemanticsNode n) {
    if (n.label == label) found = true;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(root);
  return found;
}

/// Turns off platform animations for the whole test.
///
/// Needed by any test that renders a screen with an ambient looping
/// animation: `pumpAndSettle` waits for every animation to finish, and a
/// repeating controller never does.
void disableAnimationsForTest(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const _NoAnimations();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

class _NoAnimations implements AccessibilityFeatures {
  const _NoAnimations();

  @override
  bool get disableAnimations => true;

  @override
  bool get reduceMotion => true;

  // AccessibilityFeatures gains members between Flutter versions, so the
  // rest are forwarded rather than listed. Hand-implementing the full
  // interface breaks on every SDK bump.
  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

/// Storage for a test that pumps the **whole app**, with nothing left to
/// read from the bundle.
///
/// `StrataApp` brings every store with it — auth, profile, wallet,
/// transactions, recipients, notifications — and each one seeds itself from
/// `assets/data/` when storage is empty. That asset read is the trap
/// described in CLAUDE.md: the first test in a file completes it, and every
/// test after that hangs on a bundle load that never returns. Pre-seeding
/// all of them keeps a full-app test deterministic and fast.
///
/// Pass to `SharedPreferences.setMockInitialValues` in `setUp`.
Map<String, Object> fullAppPrefs({
  String authStage = 'signedIn',
  List<Map<String, Object?>>? cards,
  List<Map<String, Object?>> transactions = const [],
  List<Map<String, Object?>> recipients = const [],
  List<Map<String, Object?>> notifications = const [],
  String themeMode = 'system',
  bool showDemoHints = true,
}) =>
    {
      'strata.auth.stage.v1': authStage,
      'strata.profile.v1': jsonEncode({
        'name': 'Olympicson',
        'email': 'hello@flutterzip.com',
        'handle': '@olympicson',
        'avatar': null,
        'preferredCurrency': 'USD',
        'themeMode': themeMode,
        'showDemoHints': showDemoHints,
      }),
      'strata.wallet.v1': jsonEncode(cards ?? [sampleCard.toJson()]),
      'strata.transactions.v1': jsonEncode(transactions),
      'strata.recipients.v1': jsonEncode(recipients),
      'strata.notifications.v1': jsonEncode(notifications),
    };
