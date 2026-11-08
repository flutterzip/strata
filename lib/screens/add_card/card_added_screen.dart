import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/payment_card.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/stage_transition.dart';

/// Confirmation after a card is saved.
class CardAddedScreen extends StatefulWidget {
  const CardAddedScreen({super.key, required this.card});

  final PaymentCard card;

  @override
  State<CardAddedScreen> createState() => _CardAddedScreenState();
}

class _CardAddedScreenState extends State<CardAddedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _cardIn =
      Motion.stage(_c, begin: 0.0, end: 0.45, curve: Motion.emphasised);
  late final _titleIn = Motion.stage(_c, begin: 0.22, end: 0.62);
  late final _bodyIn = Motion.stage(_c, begin: 0.32, end: 0.76);
  late final _actionsIn = Motion.stage(_c, begin: 0.46, end: 1.0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              StageTransition(
                animation: _cardIn,
                rise: 28,
                child: Hero(
                  tag: 'card-${widget.card.id}',
                  child: CardFace.of(widget.card, sheen: 0.8, elevation: 1.3),
                ),
              ),
              const SizedBox(height: Space.xxxl),
              StageTransition(
                animation: _titleIn,
                child: Text('Card added', style: text.headlineSmall),
              ),
              const SizedBox(height: Space.sm),
              StageTransition(
                animation: _bodyIn,
                child: Text(
                  '${widget.card.brand.label} '
                  '${widget.card.funding.label.toLowerCase()} '
                  '${widget.card.shortMask} is ready to use.',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              StageTransition(
                animation: _actionsIn,
                rise: 22,
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _done,
                      icon: const Icon(Icons.credit_card_rounded, size: 19),
                      label: const Text('View card'),
                    ),
                    const SizedBox(height: Space.md),
                    FilledButton(onPressed: _done, child: const Text('Done')),
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
