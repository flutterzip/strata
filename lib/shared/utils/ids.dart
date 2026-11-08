/// Record ids.
///
/// `DateTime.now().millisecondsSinceEpoch` alone is not unique: two records
/// created in the same millisecond collide, which is easy to do when a flow
/// writes a transaction and a notification back to back, and which showed up
/// as two sends in a row producing one transaction. A monotonic counter is
/// appended so the id is still readable in stored JSON and still sorts
/// roughly by creation time, but cannot repeat within a session.
///
/// Not a uuid: this is local demo data a buyer reads by eye, and a
/// dependency for sixteen bytes of randomness is not worth it. Swap it here
/// if a real backend wants one.
abstract final class Ids {
  static int _counter = 0;

  /// `<prefix>_<millis>_<n>`, e.g. `t_1762500000000_3`.
  static String next(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';

  /// A filename-safe stamp, for media whose name carries its own entity and
  /// id already.
  static String stamp() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}
