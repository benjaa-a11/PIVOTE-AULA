import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/aula_logo.dart';
import '../../../core/design_system/components/pressable_scale.dart';
import '../../../core/services/security_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final service = SecurityService.instance;
    final isBiometricOn = await service.isBiometricEnabled();
    final canCheck = await service.canCheckBiometrics();
    if (isBiometricOn && canCheck && mounted) {
      setState(() => _canUseBiometrics = true);
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final authenticated =
        await SecurityService.instance.authenticateBiometrics();
    if (authenticated && mounted) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    }
  }

  void _onKeyPress(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    final valid = await SecurityService.instance.verifyPin(_pin);
    if (!mounted) return;
    if (valid) {
      HapticFeedback.lightImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'PIN incorrecto. Intentá nuevamente.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AulaLogoMark(size: 68, showGlow: true),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Pivote Aula Protegida',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ingresá tu PIN de 4 dígitos para continuar',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: isFilled ? 16 : 14,
                        height: isFilled ? 16 : 14,
                        decoration: BoxDecoration(
                          color: isFilled ? primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFilled
                                ? primary
                                : AppColors.border(context),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: _error != null
                          ? Text(
                              _error!,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.errFg(context),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (int row = 0; row < 3; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int col = 1; col <= 3; col++)
                            _KeypadButton(
                              label: (row * 3 + col).toString(),
                              onTap: () =>
                                  _onKeyPress((row * 3 + col).toString()),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_canUseBiometrics)
                        _KeypadIconButton(
                          icon: Icons.fingerprint_rounded,
                          tooltip: 'Usar biometría',
                          onTap: _authenticateWithBiometrics,
                        )
                      else
                        const SizedBox(width: 68, height: 68),
                      _KeypadButton(
                        label: '0',
                        onTap: () => _onKeyPress('0'),
                      ),
                      _KeypadIconButton(
                        icon: Icons.backspace_outlined,
                        tooltip: 'Borrar',
                        onTap: _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border(context)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.display.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _KeypadIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(
            icon,
            size: 26,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
