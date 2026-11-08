import 'package:flutter/foundation.dart';

import '../../models/recipient.dart';

/// What came of resolving what someone typed.
///
/// Every one of these is reachable in the demo, which is the point: a send
/// screen that only ever shows the happy path hides the states that matter.
enum RecipientMatchState {
  /// Nothing typed yet. Not an error.
  empty,

  /// Resolved to a confirmed account.
  found,

  /// Resolved, but the account has not been confirmed.
  unverified,

  /// Resolved to the account doing the sending.
  self,

  /// Matched nobody.
  notFound,
}

/// The outcome, with the sentence to show for it.
@immutable
class RecipientMatch {
  const RecipientMatch(this.state, {this.recipient, this.message});

  final RecipientMatchState state;

  /// Null unless the state is [RecipientMatchState.found] or
  /// [RecipientMatchState.unverified] — nothing else has a payee.
  final Recipient? recipient;

  /// What to put under the field. Null only for [RecipientMatchState.empty].
  final String? message;

  /// Whether money may be sent on this match.
  bool get sendable =>
      state == RecipientMatchState.found ||
      state == RecipientMatchState.unverified;
}

/// Turning typed text into a recipient that actually exists.
///
/// Deliberately refuses to accept free text. There is no undo on money, and
/// "@akosau" is a perfectly plausible thing to type — so an unmatched entry
/// is a reported state, never a payee invented from the input.
abstract final class RecipientLookup {
  static RecipientMatch resolve(
    String input, {
    required List<Recipient> directory,
    required String ownerHandle,
    required String ownerEmail,
  }) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return const RecipientMatch(RecipientMatchState.empty);

    final bare = q.startsWith('@') ? q.substring(1) : q;

    // You, before anything else: matching yourself against the directory
    // first would report "not found" for your own handle, which is worse
    // than useless — it suggests your own account does not exist.
    final ownerBare = ownerHandle.trim().toLowerCase().startsWith('@')
        ? ownerHandle.trim().toLowerCase().substring(1)
        : ownerHandle.trim().toLowerCase();
    if (bare == ownerBare || q == ownerEmail.trim().toLowerCase()) {
      return const RecipientMatch(
        RecipientMatchState.self,
        message: 'That is your own account. Choose someone else.',
      );
    }

    for (final r in directory) {
      final matchesHandle = r.bareHandle.toLowerCase() == bare;
      final matchesEmail = r.email.toLowerCase() == q;
      final matchesName = r.name.trim().toLowerCase() == q;
      if (!matchesHandle && !matchesEmail && !matchesName) continue;

      return r.verified
          ? RecipientMatch(
              RecipientMatchState.found,
              recipient: r,
              message: '${r.name} · ${r.handle}',
            )
          : RecipientMatch(
              RecipientMatchState.unverified,
              recipient: r,
              message: '${r.name} · ${r.handle} has not been confirmed '
                  'yet. Check the details before you send.',
            );
    }

    return const RecipientMatch(
      RecipientMatchState.notFound,
      message: 'No one matches that handle or email. Check it, or add them '
          'as a recipient first.',
    );
  }

  /// Partial matches, for the list under the field as someone types.
  ///
  /// Substring rather than exact, across name, handle and email, because the
  /// point is to find the record before the whole thing has been typed.
  static List<Recipient> suggest(String input, List<Recipient> directory) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return directory;
    final bare = q.startsWith('@') ? q.substring(1) : q;
    return [
      for (final r in directory)
        if (r.name.toLowerCase().contains(bare) ||
            r.bareHandle.toLowerCase().contains(bare) ||
            r.email.toLowerCase().contains(q))
          r,
    ];
  }

  /// Most recently used first; never-used last, alphabetically.
  ///
  /// Recency is what a send list is for — the person you paid yesterday is
  /// overwhelmingly the person you are paying now.
  static List<Recipient> ordered(List<Recipient> directory) {
    final used = [
      for (final r in directory)
        if (r.lastUsedAt != null) r,
    ]..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    final unused = [
      for (final r in directory)
        if (r.lastUsedAt == null) r,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return [...used, ...unused];
  }
}
