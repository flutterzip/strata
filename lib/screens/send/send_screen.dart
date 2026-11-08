import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/payment_card.dart';
import '../../models/recipient.dart';
import '../../providers/recipient_providers.dart';
import '../../providers/send_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/utils/amount_entry.dart';
import '../../shared/utils/send_rules.dart';
import '../../shared/utils/spend_limit.dart';
import '../../shared/widgets/strata_sheet.dart';
import 'widgets/amount_step.dart';
import 'widgets/recipient_edit_sheet.dart';
import 'widgets/recipient_step.dart';
import 'widgets/result_step.dart';
import 'widgets/review_step.dart';

/// Which part of the flow is on screen.
enum SendStep {
  recipient('Send to'),
  amount('How much'),
  review('Check and send'),
  result('Sent');

  const SendStep(this.title);

  final String title;
}

/// Send money: pick recipient, enter an amount, check it, done.
///
/// One screen with four steps rather than four routes. Nothing is written
/// until the confirm on the review step, so backing out at any point — the
/// app bar, the system back gesture, closing the flow — leaves no trace,
/// which is the whole requirement for a flow that moves money.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  static const String route = '/send';

  static const Key continueKey = Key('send-continue');
  static const Key confirmKey = Key('send-confirm');
  static const Key doneKey = Key('send-done');
  static const Key againKey = Key('send-again');
  static const Key searchKey = Key('send-search');
  static const Key noteKey = Key('send-note');
  static const Key backKey = Key('send-back');

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  SendStep _step = SendStep.recipient;

  Recipient? _recipient;
  String? _cardId;
  AmountEntry _amount = AmountEntry.empty;
  final _note = TextEditingController();

  SendOutcome? _outcome;
  bool _sending = false;

  /// Shown under the primary button when it cannot proceed. The button stays
  /// pressable and names the problem — never a dead control.
  String? _problem;

  @override
  void initState() {
    super.initState();
    // The field starts empty every time the flow opens: a search left over
    // from a previous send would silently narrow the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recipientQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<PaymentCard> get _cards =>
      ref.read(walletProvider).valueOrNull ?? const [];

  PaymentCard? get _card {
    final cards = _cards;
    if (cards.isEmpty) return null;
    return cards.firstWhere((c) => c.id == _cardId, orElse: () => cards.first);
  }

  SendCheck get _check {
    final card = _card;
    return SendRules.check(
      recipient: _recipient,
      card: card,
      amountMinor: _amount.minor,
      // A frozen card or an exhausted monthly limit has to be caught here,
      // where the amount is being typed, not discovered at the confirm.
      limit: card == null
          ? null
          : SpendLimits.statusFor(
              card,
              ref.watch(transactionsProvider).valueOrNull ?? const [],
              now: DateTime.now(),
            ),
    );
  }

  void _goBack() {
    setState(() {
      _problem = null;
      switch (_step) {
        case SendStep.recipient:
          Navigator.of(context).maybePop();
        case SendStep.amount:
          _step = SendStep.recipient;
        case SendStep.review:
          _step = SendStep.amount;
        case SendStep.result:
          // Finished: there is nothing to go back to, only out.
          Navigator.of(context).maybePop();
      }
    });
  }

  void _chooseRecipient(Recipient r) {
    setState(() {
      _recipient = r;
      _problem = null;
      _step = SendStep.amount;
    });
    HapticFeedback.selectionClick();
  }

  void _continue() {
    switch (_step) {
      case SendStep.recipient:
        final match = ref.read(recipientMatchProvider);
        if (match.sendable && match.recipient != null) {
          _chooseRecipient(match.recipient!);
          return;
        }
        setState(
            () => _problem = match.message ?? 'Choose who you are sending to.');
      case SendStep.amount:
        final check = _check;
        if (!check.ok) {
          setState(() => _problem = check.reason);
          return;
        }
        setState(() {
          _problem = null;
          _step = SendStep.review;
        });
      case SendStep.review:
        _confirm();
      case SendStep.result:
        Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirm() async {
    final recipient = _recipient;
    final card = _card;
    if (recipient == null || card == null) return;

    setState(() {
      _sending = true;
      _problem = null;
    });

    try {
      final outcome = await ref.read(sendServiceProvider).send(SendRequest(
            recipient: recipient,
            card: card,
            amountMinor: _amount.minor,
            note: _note.text,
          ));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _sending = false;
        _outcome = outcome;
        _step = SendStep.result;
      });
    } on SendRefused catch (e) {
      if (!mounted) return;
      // The balance moved under us, or something else changed between the
      // review being drawn and the confirm. Back to the amount, with why.
      setState(() {
        _sending = false;
        _step = SendStep.amount;
        _problem = e.reason;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _problem = 'Could not send that. Nothing has left your account.';
      });
    }
  }

  void _sendAnother() {
    ref.read(recipientQueryProvider.notifier).state = '';
    _note.clear();
    setState(() {
      _step = SendStep.recipient;
      _recipient = null;
      _amount = AmountEntry.empty;
      _outcome = null;
      _problem = null;
    });
  }

  Future<void> _addRecipient() => showStrataSheet<bool>(
        context,
        builder: (_) => const RecipientEditSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final check = _check;

    final body = switch (_step) {
      SendStep.recipient => RecipientStep(
          searchKey: SendScreen.searchKey,
          onChoose: _chooseRecipient,
          onAdd: _addRecipient,
        ),
      SendStep.amount => AmountStep(
          amount: _amount,
          card: card,
          cards: _cards,
          recipient: _recipient!,
          check: check,
          onDigit: (d) => setState(() {
            _amount = _amount.push(d);
            _problem = null;
          }),
          onBackspace: () => setState(() {
            _amount = _amount.backspace();
            _problem = null;
          }),
          onCard: (id) => setState(() {
            _cardId = id;
            _problem = null;
          }),
        ),
      SendStep.review => ReviewStep(
          recipient: _recipient!,
          card: card!,
          amountMinor: _amount.minor,
          resultingBalanceMinor: check.resultingBalanceMinor,
          noteController: _note,
          noteKey: SendScreen.noteKey,
        ),
      SendStep.result => ResultStep(
          recipient: _recipient!,
          card: card!,
          outcome: _outcome!,
        ),
    };

    return PopScope(
      // Nothing is written before the confirm, so leaving is always safe.
      // After the result there is nothing left to abandon either.
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_step.title),
          leading: IconButton(
            key: SendScreen.backKey,
            icon: Icon(_step == SendStep.recipient || _step == SendStep.result
                ? Icons.close_rounded
                : Icons.arrow_back_rounded),
            tooltip: _step == SendStep.recipient || _step == SendStep.result
                ? 'Close'
                : 'Back',
            onPressed: _goBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _StepRail(step: _step),
              Expanded(child: body),
              _Footer(
                step: _step,
                problem: _problem,
                sending: _sending,
                onContinue: _continue,
                onDone: () => Navigator.of(context).maybePop(),
                onAgain: _sendAnother,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where you are in the flow. Four dots rather than "Step 2 of 4": the shape
/// is read faster than the words, and the words are in the title already.
class _StepRail extends StatelessWidget {
  const _StepRail({required this.step});

  final SendStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${step.index + 1} of ${SendStep.values.length}, '
          '${step.title}',
      child: ExcludeSemantics(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.lg),
          child: Row(
            children: [
              for (final s in SendStep.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: context.motion(Motion.base),
                      curve: Motion.standard,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: Radii.brPill,
                        // Weight, not a second hue: done and to-do differ by
                        // how solid they are.
                        color: s.index <= step.index
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.problem,
    required this.sending,
    required this.onContinue,
    required this.onDone,
    required this.onAgain,
  });

  final SendStep step;
  final String? problem;
  final bool sending;
  final VoidCallback onContinue;
  final VoidCallback onDone;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (problem != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: scheme.error),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(problem!,
                      style: text.bodySmall?.copyWith(color: scheme.error)),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
          ],
          if (step == SendStep.result) ...[
            FilledButton(
              key: SendScreen.doneKey,
              onPressed: onDone,
              child: const Text('Done'),
            ),
            const SizedBox(height: Space.md),
            OutlinedButton(
              key: SendScreen.againKey,
              onPressed: onAgain,
              child: const Text('Send another'),
            ),
          ] else
            FilledButton(
              key: step == SendStep.review
                  ? SendScreen.confirmKey
                  : SendScreen.continueKey,
              // Always pressable. When it cannot proceed it says why, in the
              // row above, rather than going dead and explaining nothing.
              onPressed: sending ? null : onContinue,
              child: Text(switch (step) {
                SendStep.recipient => 'Continue',
                SendStep.amount => 'Review',
                SendStep.review => sending ? 'Sending…' : 'Send it',
                SendStep.result => 'Done',
              }),
            ),
        ],
      ),
    );
  }
}
