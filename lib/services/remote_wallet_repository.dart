import '../config/palette.dart';
import '../models/payment_card.dart';
import 'wallet_repository.dart';

/// Where a real backend plugs in.
///
/// This is a deliberately unimplemented template. Nothing in `lib/screens`
/// changes when you adopt it — every screen already talks to
/// [WalletRepository] and already renders loading, empty and error states,
/// because the local implementation is async too.
///
/// To adopt it:
///
/// 1. Add an HTTP client (`dio` is the usual choice).
/// 2. Fill in the methods below.
/// 3. Point the provider at it:
///
/// ```dart
/// // lib/providers/wallet_providers.dart
/// final walletRepositoryProvider = Provider<WalletRepository>(
///   (ref) => RemoteWalletRepository(baseUrl: 'https://api.example.com'),
/// );
/// ```
///
/// Defaults worth keeping when you do:
///
/// * 30s connect and receive timeouts.
/// * try/catch on every call, translated to a message a user can act on.
/// * Never surface a raw server error to the UI.
/// * Retry transient failures with exponential backoff.
/// * Cancel in-flight requests on dispose.
///
/// And the rule that does not change with the backend: never send, log or
/// store a full card number or security code. Tokenise at the client with
/// your payment processor's SDK and send the token.
class RemoteWalletRepository implements WalletRepository {
  const RemoteWalletRepository({required this.baseUrl});

  final String baseUrl;

  static Never _todo(String method) => throw UnimplementedError(
        'RemoteWalletRepository.$method is a template. See the class doc '
        'for how to wire it to your API.',
      );

  /// `GET $baseUrl/cards` -> `{ "cards": [ ... ] }`
  @override
  Future<List<PaymentCard>> load() async => _todo('load');

  /// `POST $baseUrl/cards` with a processor token, never a raw PAN.
  @override
  Future<PaymentCard> add(PaymentCard card) async => _todo('add');

  /// `DELETE $baseUrl/cards/{id}`
  @override
  Future<void> remove(String id) async => _todo('remove');

  /// `PATCH $baseUrl/cards/{id}` with `{ "skin": "..." }`
  @override
  Future<PaymentCard> restyle(String id, CardSkin skin) async =>
      _todo('restyle');

  /// `PATCH $baseUrl/cards/{id}` with the changed fields.
  @override
  Future<PaymentCard> update(
    String id,
    PaymentCard Function(PaymentCard) change,
  ) async =>
      _todo('update');
}
