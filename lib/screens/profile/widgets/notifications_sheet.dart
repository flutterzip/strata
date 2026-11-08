import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../models/app_notification.dart';
import '../../../providers/notification_providers.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/status_view.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// The notification centre.
///
/// Full CRUD on a notification: read it, mark it read or unread, and swipe
/// to delete. A list you can only stare at is a dead end.
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return StrataSheet(
      icon: Icons.notifications_none_rounded,
      title: 'Notifications',
      message: unread == 0
          ? 'You are all caught up.'
          : '$unread unread. Tap to read in full, swipe to delete.',
      scrollable: true,
      body: async.when(
        // A floor, not a fixed height: these carry a title and a sentence,
        // and a hard 120dp clips the sentence off the bottom.
        loading: () => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: const Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: const StatusView(
            title: 'Could not load notifications',
            message: 'Close and try again.',
            compact: true,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140),
              child: const StatusView(
                icon: Icons.inbox_outlined,
                title: 'Nothing here',
                message: 'New activity will show up in this list.',
                compact: true,
              ),
            );
          }
          return Column(
            children: [
              for (final n in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    onDismissed: (_) =>
                        ref.read(notificationsProvider.notifier).remove(n.id),
                    child: _NotificationTile(
                      notification: n,
                      onOpened: () => ref
                          .read(notificationsProvider.notifier)
                          .markRead(n.id),
                      onMarkUnread: () => ref
                          .read(notificationsProvider.notifier)
                          .markRead(n.id, read: false),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        if (unread > 0)
          FilledButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Mark all as read'),
          ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Space.xl),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: Radii.brLg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded,
              size: 19, color: scheme.onErrorContainer),
          const SizedBox(width: Space.sm),
          Text('Delete',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onErrorContainer)),
        ],
      ),
    );
  }
}

/// One notification.
///
/// Tap **opens** it — expands to the full text — and marks it read on the
/// way, because that is what opening something means. Using tap to toggle
/// read/unread, as this did first, makes the obvious gesture do the least
/// obvious thing and leaves no way to actually read a long message.
///
/// The less common action, putting it back to unread, is an explicit button
/// that only appears once expanded. Destructive removal stays on swipe.
class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.notification,
    required this.onOpened,
    required this.onMarkUnread,
  });

  final AppNotification notification;

  /// Fired the first time it is expanded.
  final VoidCallback onOpened;

  final VoidCallback onMarkUnread;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && !widget.notification.read) widget.onOpened();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = widget.notification;
    final unread = !n.read;

    return Pressable(
      onTap: _toggle,
      pressedScale: 0.99,
      enforceMinTarget: false,
      semanticLabel: '${n.title}. ${n.body}',
      semanticHint: _expanded ? 'Tap to collapse' : 'Tap to read in full',
      child: AnimatedContainer(
        duration: context.motion(Motion.base),
        curve: Motion.standard,
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: unread ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: Radii.brLg,
          border: Border.all(
            color: unread
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(n.kind.icon,
                  size: 17,
                  color: unread
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      // Unread dot plus the age, so the state is not carried
                      // by background colour alone.
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 6, right: 6),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(_ago(n.sentAt), style: text.labelSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Collapsed bodies are clamped to two lines so a long
                  // message cannot push the rest of the list off-screen.
                  AnimatedSize(
                    duration: context.motion(Motion.base),
                    curve: Motion.standard,
                    alignment: Alignment.topLeft,
                    child: Text(
                      n.body,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  if (_expanded && n.read) ...[
                    const SizedBox(height: Space.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: widget.onMarkUnread,
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Space.sm),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.mark_email_unread_outlined,
                            size: 16),
                        label: const Text('Mark unread'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
