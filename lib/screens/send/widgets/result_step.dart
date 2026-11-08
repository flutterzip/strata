import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../models/payment_card.dart';
import '../../../models/recipient.dart';
import '../../../providers/send_providers.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/amount_text.dart';

/// Step four: it happened, and here is the new balance.
///
/// The balance is the thing people check after sending money, so it is the
/// largest thing on the screen after the amount — not buried behind a tap
/// back to the cards tab.
class ResultStep extends StatefulWidget {
  const ResultStep({
    super.key,
    required this.recipient,
    required this.card,
    required this.outcome,
  });

  final Recipient recipient;
  final PaymentCard card;
  final SendOutcome outcome;

  @override
  State<ResultStep> createState() => _ResultStepState();
}

class _ResultStepState extends State<ResultStep>
    with SingleTickerProviderStateMixin {
  /// One controller, one pass, no `repeat()` — an ambient loop here would
  /// burn frames for as long as the screen is open.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _markIn = Motion.stage(_in, begin: 0.0, end: 0.45);
  late final _textIn = Motion.stage(_in, begin: 0.22, end: 0.70);
  late final _balanceIn = Motion.stage(_in, begin: 0.45, end: 1.0);

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _markIn, curve: Motion.emphasised),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: Icon(Icons.check_rounded,
                    size: 34, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          FadeTransition(
            opacity: _textIn,
            child: Column(
              children: [
                AmountText(
                  minor: widget.outcome.transaction.amountMinor.abs(),
                  currency: widget.card.currency,
                  semanticsPrefix: 'Sent',
                ),
                const SizedBox(height: Space.xs),
                Text('sent to ${widget.recipient.name}',
                    style: text.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: Space.xxl),
          FadeTransition(
            opacity: _balanceIn,
            child: Container(
              padding: const EdgeInsets.all(Space.xl),
              decoration: BoxDecoration(
                borderRadius: Radii.brXl,
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: MergeSemantics(
                child: Column(
                  children: [
                    Text(
                        '${widget.card.displayLabel} · '
                        '${widget.card.shortMask}',
                        style: text.bodySmall),
                    const SizedBox(height: Space.xs),
                    Text(
                      Money.format(
                          widget.outcome.newBalanceMinor, widget.card.currency),
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text('now available', style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            'It is in your activity list, and we have sent you a '
            'notification.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
