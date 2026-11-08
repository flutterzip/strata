import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/user_profile.dart';
import '../../providers/notification_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/profile_providers.dart';
import '../../shared/widgets/avatar_circle.dart';
import '../../shared/widgets/settings_row.dart';
import '../../shared/widgets/stage_transition.dart';
import '../../shared/widgets/status_view.dart';
import '../../shared/widgets/strata_mark.dart';
import '../../shared/widgets/strata_sheet.dart';
import 'widgets/appearance_sheet.dart';
import 'widgets/avatar_sheet.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/notifications_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _headerIn = Motion.stage(_entrance, begin: 0.0, end: 0.45);
  late final _accountIn = Motion.stage(_entrance, begin: 0.18, end: 0.66);
  late final _appIn = Motion.stage(_entrance, begin: 0.34, end: 0.86);

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProfile(UserProfile profile) async {
    final saved = await showStrataSheet<bool>(
      context,
      builder: (_) => EditProfileSheet(profile: profile),
    );
    if (saved == true && mounted) _toast('Profile updated');
  }

  Future<void> _openNotifications() => showStrataSheet<void>(
        context,
        builder: (_) => const NotificationsSheet(),
      );

  Future<void> _openAppearance(ThemeMode mode) => showStrataSheet<void>(
        context,
        builder: (_) => AppearanceSheet(current: mode),
      );

  Future<void> _editAvatar(bool hasAvatar) => showStrataSheet<void>(
        context,
        builder: (_) => AvatarSheet(hasAvatar: hasAvatar),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider);
    final unread = ref.watch(unreadCountProvider);
    final pendingAvatar = ref.watch(pendingAvatarProvider);

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, __) => StatusView(
            icon: Icons.person_off_outlined,
            title: 'Could not load your profile',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(profileProvider),
          ),
          data: (profile) => ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.md, Space.xl, Space.huge),
            children: [
              StageTransition(
                animation: _headerIn,
                child: _ProfileHeader(
                  profile: profile,
                  pendingAvatar: pendingAvatar,
                  onEditAvatar: () => _editAvatar(
                      profile.avatar != null || pendingAvatar != null),
                ),
              ),
              const SizedBox(height: Space.xxxl),
              StageTransition(
                animation: _accountIn,
                child: SettingsGroup(
                  title: 'Account',
                  children: [
                    SettingsRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit profile',
                      subtitle: 'Name, email and handle',
                      onTap: () => _editProfile(profile),
                    ),
                    SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: unread == 0
                          ? 'All caught up'
                          : '$unread waiting for you',
                      badgeCount: unread,
                      onTap: _openNotifications,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              StageTransition(
                animation: _appIn,
                child: SettingsGroup(
                  title: 'App',
                  children: [
                    SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: switch (profile.themeMode) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        ThemeMode.system => 'Match device',
                      },
                      onTap: () => _openAppearance(profile.themeMode),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.pendingAvatar,
    required this.onEditAvatar,
  });

  final UserProfile profile;

  /// A picture chosen moments ago whose file may still be being written.
  final Uint8List? pendingAvatar;

  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StrataMark(size: 26, color: scheme.onSurface),
            const Spacer(),
          ],
        ),
        const SizedBox(height: Space.xxl),
        Row(
          children: [
            AvatarCircle(
              key: AvatarKeys.avatar,
              initials: profile.initials,
              avatar: profile.avatar,
              pendingBytes: pendingAvatar,
              size: AvatarSize.header,
              showEditAffordance: true,
              semanticLabel: profile.avatar == null && pendingAvatar == null
                  ? 'Profile picture, currently your initials'
                  : 'Profile picture',
              semanticHint: 'Opens options to change or remove it',
              onTap: onEditAvatar,
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(profile.name,
                        style: text.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(profile.email,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
