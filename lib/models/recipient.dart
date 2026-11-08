import 'package:flutter/widgets.dart';

import '../services/media_ref.dart';

/// Someone money can be sent to.
///
/// Carries both a handle and an email because that is what people actually
/// type, and a send must resolve to a record that exists rather than
/// accepting free text — there is no "undo" on money that went to a string
/// somebody mistyped.
@immutable
class Recipient {
  const Recipient({
    required this.id,
    required this.name,
    required this.handle,
    required this.email,
    this.verified = false,
    this.avatar,
    this.lastUsedAt,
  });

  final String id;
  final String name;

  /// Always stored with the leading `@`, so there is one spelling of it.
  final String handle;

  final String email;

  /// Whether the account behind this record has been confirmed.
  ///
  /// An unverified recipient is still sendable — plenty of real transfers go
  /// to accounts the bank has not confirmed — but it is said out loud before
  /// the money moves rather than discovered afterwards.
  final bool verified;

  final MediaRef? avatar;

  /// Null means never sent to. Orders the list, newest first.
  final DateTime? lastUsedAt;

  /// Up to two letters, for the fallback avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// The handle without its `@`, for comparing what someone typed.
  String get bareHandle =>
      handle.startsWith('@') ? handle.substring(1) : handle;

  String get describedForAccessibility =>
      '$name, $handle${verified ? '' : ', not yet confirmed'}';

  factory Recipient.fromJson(Map<String, dynamic> json) => Recipient(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        handle: _normaliseHandle(json['handle'] as String? ?? ''),
        email: (json['email'] as String? ?? '').trim(),
        verified: json['verified'] as bool? ?? false,
        avatar: MediaRef.parse(json['avatar'] as String?),
        lastUsedAt:
            DateTime.tryParse(json['lastUsedAt'] as String? ?? '')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'email': email,
        'verified': verified,
        'avatar': avatar?.encoded,
        'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
      };

  /// Pass [clearLastUsed] to forget that this recipient was ever used; a
  /// null [lastUsedAt] means "unchanged".
  Recipient copyWith({
    String? name,
    String? handle,
    String? email,
    bool? verified,
    MediaRef? avatar,
    bool clearAvatar = false,
    DateTime? lastUsedAt,
    bool clearLastUsed = false,
  }) =>
      Recipient(
        id: id,
        name: name ?? this.name,
        handle: handle == null ? this.handle : _normaliseHandle(handle),
        email: email ?? this.email,
        verified: verified ?? this.verified,
        avatar: clearAvatar ? null : (avatar ?? this.avatar),
        lastUsedAt: clearLastUsed ? null : (lastUsedAt ?? this.lastUsedAt),
      );

  /// One `@`, always leading. Stored this way so a handle typed with or
  /// without it, or saved from a form either way, is the same handle.
  static String _normaliseHandle(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final bare = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return '@${bare.trim()}';
  }

  @override
  bool operator ==(Object other) =>
      other is Recipient &&
      other.id == id &&
      other.name == name &&
      other.handle == handle &&
      other.email == email &&
      other.verified == verified &&
      other.avatar == avatar &&
      other.lastUsedAt == lastUsedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, handle, email, verified, avatar, lastUsedAt);
}
