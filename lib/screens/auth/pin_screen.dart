import '../../config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/stage_transition.dart';
import '../../shared/widgets/strata_mark.dart';
import 'widgets/auth_backdrop.dart';
import 'widgets/auth_banner.dart';
import 'widgets/pin_keypad.dart';

/// Create a PIN, then confirm it.
///
/// Its own layout rather than [AuthScaffold]: a keypad screen wants the dots
/// optically centred and the keys thumb-reachable at the bottom, which a
/// scrolling form cannot promise.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, this.length = 4});

  final int length;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

enum _PinStep { create, confirm }

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _titleIn = Motion.stage(_entrance, begin: 0.0, end: 0.45);
  late final _dotsIn = Motion.stage(_entrance, begin: 0.16, end: 0.62);
  late final _padIn = Motion.stage(_entrance, begin: 0.30, end: 0.90);

  _PinStep _step = _PinStep.create;
  String _first = '';
  String _entry = '';
  String? _error;
  int _shake = 0;
  bool _busy = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _reject(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _shake++;
      _entry = '';
    });
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _entry.length >= widget.length) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length < widget.length) return;

    if (_step == _PinStep.create) {
      // A PIN that is all one digit, or a straight run, is not a PIN.
      if (RegExp(r'^(.)\1+$').hasMatch(_entry)) {
        _reject('Pick something less guessable than ${_entry[0]} repeated.');
        return;
      }
      setState(() {
        _first = _entry;
        _entry = '';
        _step = _PinStep.confirm;
      });
      HapticFeedback.selectionClick();
      return;
    }

    if (_entry != _first) {
      _reject('Those did not match. Start again.');
      setState(() {
        _step = _PinStep.create;
        _first = '';
      });
      return;
    }

    setState(() => _busy = true);
    await ref.read(authProvider.notifier).setPin(_entry);
    if (mounted) HapticFeedback.mediumImpact();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final creating = _step == _PinStep.create;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.xxl, Space.sm, Space.xxl, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    StrataMark(size: 26, color: scheme.onSurface),
                  ],
                ),
              ),
              const Spacer(),
              StageTransition(
                animation: _titleIn,
                child: Column(
                  children: [
                    Text(
                      creating ? 'Set a PIN' : 'Confirm your PIN',
                      style: text.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.sm),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.huge),
                      child: Text(
                        creating
                            ? 'You will use this to open ${AppBrand.name}. '
                                '${widget.length} digits.'
                            : 'Enter the same ${widget.length} digits again.',
                        style: text.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxxl),
              StageTransition(
                animation: _dotsIn,
                child: Shaker(
                  trigger: _shake == 0 ? null : _shake,
                  child: PinDots(
                    filled: _entry.length,
                    length: widget.length,
                    hasError: _error != null,
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                  child: _error != null
                      ? AuthBanner.error(message: _error!, shrink: true)
                      : const SizedBox.shrink(),
                ),
              ),
              const Spacer(),
              StageTransition(
                animation: _padIn,
                rise: 26,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.xl, 0, Space.xl, Space.lg),
                  child: PinKeypad(
                    enabled: !_busy,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
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
