import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/services/local_wallet_repository.dart';

/// Runs against real iOS NSUserDefaults, not a mock.
///
/// A second [LocalWalletRepository] instance reading back what the first
/// wrote is exactly the relaunch case: nothing is shared in memory between
/// them, so a hit can only come from disk.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const probe = PaymentCard(
    id: 'c_persist_probe',
    last4: '4242',
    brand: CardBrand.visa,
    funding: CardFunding.credit,
    holder: 'PERSISTENCE PROBE',
    expiryMonth: 12,
    expiryYear: 2034,
    skin: CardSkin.stone,
    balanceMinor: 1234,
    currency: 'USD',
  );

  testWidgets('a card written to disk is read back by a new instance',
      (tester) async {
    await LocalWalletRepository().resetToSeed();

    final seeded = await LocalWalletRepository().load();
    expect(seeded.map((c) => c.id), isNot(contains(probe.id)));

    await LocalWalletRepository().add(probe);

    final reloaded = await LocalWalletRepository().load();
    expect(reloaded.map((c) => c.id), contains(probe.id),
        reason: 'the added card must come back from disk');
    expect(reloaded.length, seeded.length + 1);

    final restored = reloaded.firstWhere((c) => c.id == probe.id);
    expect(restored.last4, '4242');
    expect(restored.skin, CardSkin.stone);
    expect(restored.brand, CardBrand.visa);
    expect(restored.expiryLabel, '12/34');
  });

  testWidgets('restyle and remove also survive a new instance',
      (tester) async {
    await LocalWalletRepository().resetToSeed();
    final seeded = await LocalWalletRepository().load();
    final target = seeded.first.id;

    await LocalWalletRepository().restyle(target, CardSkin.bone);
    expect((await LocalWalletRepository().load()).first.skin,
        CardSkin.bone);

    await LocalWalletRepository().remove(target);
    expect((await LocalWalletRepository().load()).map((c) => c.id),
        isNot(contains(target)));
  });

  testWidgets('reset restores the bundled seed', (tester) async {
    await LocalWalletRepository().add(probe);
    final reset = await LocalWalletRepository().resetToSeed();
    expect(reset.map((c) => c.id), isNot(contains(probe.id)));
    expect((await LocalWalletRepository().load()).length, reset.length);
  });
}
