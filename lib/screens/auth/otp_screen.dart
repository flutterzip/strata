import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../shared/widgets/busy_button.dart';
import 'widgets/auth_banner.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/otp_field.dart';
import 'widgets/pin_keypad.dart';

/// Step two of a reset: enter the six-digit code.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.onBack,
    required this.onVerified,
  });

  final String email;
  final VoidCallback onBack;
  final VoidCallback onVerified;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _ticker;
  int _secondsLeft = 30;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = 30);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyCode(code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onVerified();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = e.message;
        _shake++;
        _code.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final demo = ref.watch(demoAccountProvider).valueOrNull;

    return AuthScaffold(
      eyebrow: 'Verify',
      title: 'Enter your\nsix-digit code',
      subtitle: 'Sent to ${widget.email}. It expires in ten minutes.',
      onBack: widget.onBack,
      fields: [
        if (_error != null) ...[
          AuthBanner.error(message: _error!),
          const SizedBox(height: Space.lg),
        ],
        Shaker(
          trigger: _shake == 0 ? null : _shake,
          child: OtpField(
            controller: _code,
            hasError: _error != null,
            onCompleted: _busy ? null : _verify,
          ),
        ),
        const SizedBox(height: Space.xl),
        if (demo != null && ref.watch(showDemoHintsProvider))
          AuthBanner.info(message: 'Demo code: ${demo.otp}', shrink: true),
        const SizedBox(height: Space.xl),
        Center(
          child: _secondsLeft > 0
              ? Text('Resend in ${_secondsLeft}s', style: text.bodySmall)
              : TextButton(
                  onPressed: () {
                    _startCountdown();
                    HapticFeedback.lightImpact();
                  },
                  child: const Text('Resend code'),
                ),
        ),
      ],
      footer: BusyButton(
        label: 'Verify',
        busy: _busy,
        busyLabel: 'Checking code',
        onPressed: _code.text.length < 6 ? null : () => _verify(_code.text),
      ),
    );
  }
}
