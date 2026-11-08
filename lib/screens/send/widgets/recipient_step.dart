import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/recipient.dart';
import '../../../providers/recipient_providers.dart';
import '../../../shared/utils/recipient_lookup.dart';
import '../../../shared/widgets/avatar_circle.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/status_view.dart';
import '../../../shared/widgets/strata_sheet.dart';
import 'recipient_edit_sheet.dart';

/// Step one: who the money is going to.
///
/// Typed text is resolved against stored recipients rather than accepted as
/// it stands. There is no undo on money, and "@akosau" is a perfectly
/// plausible thing to type — so an unmatched entry is a reported state, not
/// a payee invented from the input.
class RecipientStep extends ConsumerStatefulWidget {
  const RecipientStep({
    super.key,
    required this.searchKey,
    required this.onChoose,
    required this.onAdd,
  });

  final Key searchKey;
  final ValueChanged<Recipient> onChoose;
  final VoidCallback onAdd;

  @override
  ConsumerState<RecipientStep> createState() => _RecipientStepState();
}

class _RecipientStepState extends ConsumerState<RecipientStep> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(recipientQueryProvider);
    _controller.addListener(_onType);
  }

  @override
  void dispose() {
    _controller.removeListener(_onType);
    _controller.dispose();
    super.dispose();
  }

  void _onType() {
    if (ref.read(recipientQueryProvider) == _controller.text) return;
    ref.read(recipientQueryProvider.notifier).state = _controller.text;
  }

  Future<void> _edit(Recipient r) async {
    final changed = await showStrataSheet<bool>(
      context,
      builder: (_) => RecipientEditSheet(existing: r),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r.name} updated')),
      );
    }
  }

  Future<void> _delete(Recipient r) async {
    final ok = await confirmAction(
      context,
      icon: Icons.person_remove_outlined,
      title: 'Remove ${r.name}?',
      message: 'They will no longer appear here. Transfers you have already '
          'made to them stay in your history.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(recipientsProvider.notifier).remove(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${r.name} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(recipientsProvider.notifier).create(r),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove that. Try again.')),
      );
    }
  }

  Future<void> _options(Recipient r) => showStrataSheet<void>(
        context,
        builder: (sheetContext) => StrataSheet(
          icon: Icons.more_horiz_rounded,
          title: r.name,
          message: '${r.handle} · ${r.email}',
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _edit(r);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              key: RecipientKeys.delete,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _delete(r);
              },
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(sheetContext).colorScheme.error),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recipientsProvider);
    final match = ref.watch(recipientMatchProvider);
    final suggestions = ref.watch(recipientSuggestionsProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: widget.searchKey,
                controller: _controller,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Handle, email or name',
                  prefixIcon:
                      const Icon(Icons.alternate_email_rounded, size: 20),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Clear',
                          onPressed: _controller.clear,
                        ),
                ),
              ),
              const SizedBox(height: Space.sm),
              _MatchLine(match: match),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Expanded(
          child: async.when(
            loading: () => Center(
              child: Semantics(
                label: 'Loading your recipients',
                child: const CircularProgressIndicator.adaptive(),
              ),
            ),
            error: (_, __) => StatusView(
              icon: Icons.cloud_off_rounded,
              title: 'Recipients are unavailable',
              message: 'We could not read your saved recipients.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(recipientsProvider),
            ),
            data: (all) {
              if (all.isEmpty) {
                return StatusView(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'No recipients yet',
                  message: 'Add someone to send money to.',
                  actionLabel: 'Add a recipient',
                  onAction: widget.onAdd,
                  emphasised: true,
                );
              }
              if (suggestions.isEmpty) {
                return StatusView(
                  icon: Icons.search_off_rounded,
                  title: 'No one matches that',
                  message: 'Check the handle or email, or add them as a '
                      'recipient.',
                  actionLabel: 'Add a recipient',
                  onAction: widget.onAdd,
                );
              }
              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      _controller.text.trim().isEmpty ? 'Recent' : 'Matches',
                      style: text.labelMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  for (final r in RecipientLookup.ordered(suggestions))
                    _RecipientRow(
                      key: ValueKey(r.id),
                      recipient: r,
                      onTap: () => widget.onChoose(r),
                      onOptions: () => _options(r),
                    ),
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    key: RecipientKeys.add,
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add a recipient'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The resolved state of what was typed. Every branch has words and an icon;
/// none of them is colour alone.
class _MatchLine extends StatelessWidget {
  const _MatchLine({required this.match});

  final RecipientMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.state == RecipientMatchState.empty || match.message == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final (icon, colour) = switch (match.state) {
      RecipientMatchState.found => (
          Icons.check_circle_outline_rounded,
          scheme.primary
        ),
      RecipientMatchState.unverified => (
          Icons.info_outline_rounded,
          scheme.error
        ),
      RecipientMatchState.self => (Icons.person_outline_rounded, scheme.error),
      RecipientMatchState.notFound => (
          Icons.help_outline_rounded,
          scheme.error
        ),
      RecipientMatchState.empty => (Icons.circle_outlined, scheme.outline),
    };

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(match.message!,
                style: text.bodySmall?.copyWith(color: colour)),
          ),
        ],
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    super.key,
    required this.recipient,
    required this.onTap,
    required this.onOptions,
  });

  final Recipient recipient;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: recipient.describedForAccessibility,
            hint: 'Send money to them',
            child: ExcludeSemantics(
              child: Pressable(
                onTap: onTap,
                pressedScale: 0.985,
                enforceMinTarget: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Row(
                    children: [
                      AvatarCircle(
                        initials: recipient.initials,
                        avatar: recipient.avatar,
                        size: AvatarSize.row,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(recipient.name,
                                style: text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: Space.xxs),
                            Text(recipient.handle,
                                style: text.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (!recipient.verified)
                        Padding(
                          padding: const EdgeInsets.only(left: Space.sm),
                          child: Tooltip(
                            message: 'Not confirmed',
                            child: Icon(Icons.info_outline_rounded,
                                size: 16, color: scheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          tooltip: 'Options for ${recipient.name}',
          onPressed: onOptions,
        ),
      ],
    );
  }
}
