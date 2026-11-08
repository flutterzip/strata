import 'package:flutter/material.dart';

enum NotificationKind {
  payment(Icons.arrow_downward_rounded),
  security(Icons.shield_outlined),
  system(Icons.description_outlined);

  const NotificationKind(this.icon);
  final IconData icon;

  static NotificationKind parse(String? raw) =>
      NotificationKind.values.asNameMap()[raw] ?? NotificationKind.system;
}

/// Seeded from `assets/data/notifications.json`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.read,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        sentAt: sentAt,
        read: read ?? this.read,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.parse(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'read': read,
      };
}
