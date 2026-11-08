import 'package:flutter/material.dart';

import '../services/media_ref.dart';

/// The signed-in person. Seeded from `assets/data/profile.json`.
@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.handle,
    this.avatar,
    this.preferredCurrency = 'USD',
    this.themeMode = ThemeMode.system,
    this.showDemoHints = true,
  });

  final String name;
  final String email;
  final String handle;
  final MediaRef? avatar;
  final String preferredCurrency;
  final ThemeMode themeMode;

  /// Whether the "this is demo data" notes are visible. On by default so a
  /// first-time viewer is never confused about whose account they are
  /// looking at, and off in one tap for screenshots and demos.
  final bool showDemoHints;

  /// Up to two letters, for the fallback avatar when there is no image.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// Pass [clearAvatar] to remove the picture. A null [avatar] means
  /// "unchanged", so it cannot express "delete it" on its own.
  UserProfile copyWith({
    String? name,
    String? email,
    String? handle,
    MediaRef? avatar,
    bool clearAvatar = false,
    String? preferredCurrency,
    ThemeMode? themeMode,
    bool? showDemoHints,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        handle: handle ?? this.handle,
        avatar: clearAvatar ? null : (avatar ?? this.avatar),
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
        themeMode: themeMode ?? this.themeMode,
        showDemoHints: showDemoHints ?? this.showDemoHints,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? 'There',
        email: json['email'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        avatar: MediaRef.parse(json['avatar'] as String?),
        preferredCurrency: json['preferredCurrency'] as String? ?? 'USD',
        themeMode: switch (json['themeMode'] as String?) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        showDemoHints: json['showDemoHints'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'handle': handle,
        'avatar': avatar?.encoded,
        'preferredCurrency': preferredCurrency,
        'themeMode': themeMode.name,
        'showDemoHints': showDemoHints,
      };

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.email == email &&
      other.handle == handle &&
      other.avatar == avatar &&
      other.preferredCurrency == preferredCurrency &&
      other.themeMode == themeMode &&
      other.showDemoHints == showDemoHints;

  @override
  int get hashCode => Object.hash(
      name, email, handle, avatar, preferredCurrency, themeMode, showDemoHints);
}
