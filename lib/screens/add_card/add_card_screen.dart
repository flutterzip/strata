import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../config/palette.dart';
import '../../models/card_brand.dart';
import '../../models/payment_card.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/utils/card_formatters.dart';
import '../../shared/utils/card_validation.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/stage_transition.dart';
import 'widgets/skin_picker.dart';

/// Add-card form with a preview that mirrors entry in real time.
///
/// Entrance uses the single-controller-plus-[Interval] pattern: one ticker
/// drives every staged element, so the steps cannot drift apart and the
/// screen costs one animation clock instead of six.
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _previewIn = Motion.stage(_entrance, begin: 0.00, end: 0.42);
  late final _skinIn = Motion.stage(_entrance, begin: 0.18, end: 0.56);
  late final _fieldsIn = Motion.stage(_entrance, begin: 0.26, end: 0.72);
  late final _ctaIn = Motion.stage(_entrance, begin: 0.44, end: 1.00);

  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _holder = TextEditingController();

  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvcFocus = FocusNode();
  final _holderFocus = FocusNode();
  final _nicknameFocus = FocusNode();

  CardSkin _skin = CardSkin.forest;
  CardBrand _brand = CardBrand.unknown;
  bool _submitting = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nickname, _number, _expiry, _cvc, _holder]) {
      c.addListener(_onEdit);
    }
  }

  @override
  void dispose() {
    for (final c in [_nickname, _number, _expiry, _cvc, _holder]) {
      c.dispose();
    }
    for (final f in [
      _numberFocus,
      _expiryFocus,
      _cvcFocus,
      _holderFocus,
      _nicknameFocus,
    ]) {
      f.dispose();
    }
    _entrance.dispose();
    super.dispose();
  }

  void _onEdit() {
    final detected = CardBrand.detect(CardValidation.digitsOnly(_number.text));
    if (detected != _brand) {
      // The network revealing itself is a moment worth feeling.
      if (detected.isKnown) HapticFeedback.selectionClick();
      setState(() => _brand = detected);
    } else {
      setState(() {});
    }
  }

  bool get _isComplete =>
      CardValidation.number(_number.text) == null &&
      CardValidation.expiry(_expiry.text) == null &&
      CardValidation.cvc(_cvc.text, _brand) == null &&
      CardValidation.holder(_holder.text) == null;

  /// The first field that is not yet valid, with the reason why.
  ///
  /// A disabled button that explains nothing is a dead end: the user cannot
  /// tell whether the app is broken or their input is. The button therefore
  /// stays pressable, and pressing it says what is wrong and moves focus
  /// there.
  ({String reason, FocusNode focus})? get _firstProblem {
    final checks = <({String? reason, FocusNode focus})>[
      (reason: CardValidation.number(_number.text), focus: _numberFocus),
      (reason: CardValidation.expiry(_expiry.text), focus: _expiryFocus),
      (reason: CardValidation.cvc(_cvc.text, _brand), focus: _cvcFocus),
      (reason: CardValidation.holder(_holder.text), focus: _holderFocus),
    ];
    for (final c in checks) {
      if (c.reason != null) return (reason: c.reason!, focus: c.focus);
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);

    final problem = _firstProblem;
    if (problem != null) {
      HapticFeedback.heavyImpact();
      problem.focus.requestFocus();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(problem.reason)));
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _submitting = true);
    final card = PaymentCard.fromEntry(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      number: _number.text,
      holder: _holder.text,
      expiry: _expiry.text,
      skin: _skin,
      funding: CardFunding.credit,
      nickname: _nickname.text,
      balanceMinor: 0,
      currency: 'USD',
    );
    try {
      await ref.read(walletProvider.notifier).add(card);
      // Land the carousel on the card that was just created.
      final count = ref.read(walletProvider).valueOrNull?.length ?? 1;
      ref.read(focusedCardIndexProvider.notifier).state = count - 1;
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context)
          .pushReplacementNamed('/card-added', arguments: card);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not save that card. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final digits = CardValidation.digitsOnly(_number.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.sm, Space.xl, Space.huge),
            children: [
              StageTransition(
                animation: _previewIn,
                child: CardFace(
                  skin: _skin,
                  brand: _brand,
                  funding: CardFunding.credit,
                  label: _nickname.text.trim().isEmpty
                      ? null
                      : _nickname.text.trim(),
                  numberText: digits.isEmpty
                      ? null
                      : CardValidation.format(digits, _brand).padRight(1),
                  holder: _holder.text,
                  expiry: _expiry.text,
                  sheen: 0.6,
                ),
              ),
              const SizedBox(height: Space.xl),
              StageTransition(
                animation: _skinIn,
                child: SkinPickerRow(
                  selected: _skin,
                  onChanged: (s) => setState(() => _skin = s),
                ),
              ),
              const SizedBox(height: Space.xl),
              StageTransition(
                animation: _fieldsIn,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _number,
                      focusNode: _numberFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.creditCardNumber],
                      inputFormatters: [CardNumberFormatter()],
                      validator: (_) => CardValidation.number(_number.text),
                      onFieldSubmitted: (_) => _expiryFocus.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Card number',
                        hintText: '0000 0000 0000 0000',
                        suffixIcon: _BrandTag(brand: _brand),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiry,
                            focusNode: _expiryFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [ExpiryFormatter()],
                            validator: (_) =>
                                CardValidation.expiry(_expiry.text),
                            onFieldSubmitted: (_) => _cvcFocus.requestFocus(),
                            decoration: const InputDecoration(
                              labelText: 'Expiry',
                              hintText: 'MM/YY',
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _cvc,
                            focusNode: _cvcFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            obscureText: true,
                            maxLength: _brand.cvcLength,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (_) =>
                                CardValidation.cvc(_cvc.text, _brand),
                            onFieldSubmitted: (_) =>
                                _holderFocus.requestFocus(),
                            decoration: InputDecoration(
                              labelText: 'Security code',
                              hintText: '0' * _brand.cvcLength,
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _holder,
                      focusNode: _holderFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.creditCardName],
                      validator: (_) => CardValidation.holder(_holder.text),
                      onFieldSubmitted: (_) => _nicknameFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Name on card',
                        hintText: 'As it appears on the card',
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    // What the owner calls it. Optional, and last, because
                    // the required details come first.
                    TextFormField(
                      controller: _nickname,
                      focusNode: _nicknameFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Card name',
                        hintText: 'Everyday, Travel, Household\u2026',
                        helperText:
                            'Optional. Shown on the card and in your wallet.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              StageTransition(
                animation: _ctaIn,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: Space.sm),
                        Expanded(
                            child: Text(
                                'Your details are encrypted and never leave this device.',
                                style: text.bodySmall)),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    _SubmitButton(
                      complete: _isComplete,
                      busy: _submitting,
                      onPressed: _submit,
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

class _BrandTag extends StatelessWidget {
  const _BrandTag({required this.brand});
  final CardBrand brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.md),
      child: AnimatedSwitcher(
        duration: context.motion(Motion.base),
        switchInCurve: Motion.emphasised,
        transitionBuilder: (child, a) => FadeTransition(
            opacity: a, child: ScaleTransition(scale: a, child: child)),
        child: brand.isKnown
            ? Align(
                key: ValueKey(brand),
                widthFactor: 1,
                child: Text(
                  brand.short.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.complete,
    required this.busy,
    required this.onPressed,
  });

  /// Whether every field currently validates. Drives appearance only — the
  /// button stays pressable either way so it can explain itself.
  final bool complete;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !busy,
      label: 'Add card',
      hint: complete ? null : 'Some details still need fixing',
      child: AnimatedScale(
        scale: complete ? 1 : 0.985,
        duration: context.motion(Motion.gentle),
        curve: Motion.standard,
        child: FilledButton(
          style: complete
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: scheme.primary.withValues(alpha: 0.38),
                ),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Add card'),
        ),
      ),
    );
  }
}
