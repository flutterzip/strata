import '../models/recipient.dart';

/// Contract for recipient storage. Async even though the local one is not,
/// so a real directory service can replace it without touching a widget.
abstract interface class RecipientRepository {
  Future<List<Recipient>> load();
  Future<Recipient> add(Recipient recipient);

  /// Throws [StateError] when the id is gone, rather than silently doing
  /// nothing and leaving the UI showing an edit that was never stored.
  Future<Recipient> update(
    String id,
    Recipient Function(Recipient) change,
  );

  Future<void> remove(String id);
}

/// In-memory implementation, for tests and for exercising loading states.
class InMemoryRecipientRepository implements RecipientRepository {
  InMemoryRecipientRepository({List<Recipient>? seed, this.latency})
      : _items = [...(seed ?? const <Recipient>[])];

  final List<Recipient> _items;
  final Duration? latency;

  Future<void> _settle() async {
    if (latency != null) await Future<void>.delayed(latency!);
  }

  @override
  Future<List<Recipient>> load() async {
    await _settle();
    return List.unmodifiable(_items);
  }

  @override
  Future<Recipient> add(Recipient recipient) async {
    await _settle();
    _items.add(recipient);
    return recipient;
  }

  @override
  Future<Recipient> update(
    String id,
    Recipient Function(Recipient) change,
  ) async {
    await _settle();
    final i = _items.indexWhere((r) => r.id == id);
    if (i == -1) throw StateError('No recipient $id');
    return _items[i] = change(_items[i]);
  }

  @override
  Future<void> remove(String id) async {
    await _settle();
    _items.removeWhere((r) => r.id == id);
  }
}
