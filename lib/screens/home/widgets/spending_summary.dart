import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../config/palette.dart';
import '../../../models/spend_category.dart';
import '../../../providers/spending_providers.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/status_view.dart';

/// "Spent this week", derived from the transaction list.
///
/// A single stacked bar rather than a pie: proportions along one axis are far
/// easier to compare than angles, and it survives five categories without a
/// legend fight.
///
/// Reads [spendingProvider], which is a view over transactions rather than a
/// file of its own — editing a transaction moves this chart.
class SpendingSummary extends ConsumerWidget {
  const SpendingSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spendingProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: Radii.brXl,
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: async.when(
        // A floor, not a fixed height: these states carry a title and a
        // sentence, and a hard 96dp clips the sentence off the bottom.
        loading: () => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: const Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: const StatusView(
            title: 'Spending is unavailable',
            message: 'Pull to refresh to try again.',
            compact: true,
          ),
        ),
        data: (summary) => _Summary(summary: summary),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final SpendSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = summary.totalMinor;
    final items = summary.categories;

    if (items.isEmpty || total == 0) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: const StatusView(
          title: 'Nothing spent this week',
          message: 'Payments from the last seven days appear here.',
          compact: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The label needs an escape route: at the top of the text-scale
            // range on a narrow phone it and the total together are wider
            // than the card, and a bare Row has nowhere to put the excess.
            Expanded(
              child: Text(
                summary.periodLabel,
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(Money.format(total, summary.currency),
                style: text.titleMedium),
          ],
        ),
        const SizedBox(height: Space.lg),
        Semantics(
          label: 'Spending by category, total '
              '${Money.format(total, summary.currency)}',
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: context.motion(const Duration(milliseconds: 650)),
              curve: Motion.standard,
              builder: (context, t, _) => ClipRRect(
                borderRadius: Radii.brPill,
                child: SizedBox(
                  height: 10,
                  child: Row(
                    // Without stretch, a childless ColoredBox gets loose
                    // cross-axis constraints and collapses to zero height.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, c) in items.indexed)
                        Expanded(
                          flex: (c.minor * 1000 / total).round(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: ColoredBox(
                              color:
                                  ChartRamp.at(i, isDark).withValues(alpha: t),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.sm,
          children: [
            for (final (i, c) in items.indexed)
              MergeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ChartRamp.at(i, isDark)),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(c.label, style: text.bodySmall),
                    const SizedBox(width: Space.xs),
                    Text(Money.format(c.minor, summary.currency),
                        style: text.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
