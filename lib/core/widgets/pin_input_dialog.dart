import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/crispy_spacing.dart';
import '../../features/profiles/presentation/providers/biometric_provider.dart';
import '../../features/settings/presentation/providers/pin_lockout_provider.dart';

/// Sentinel profile ID used by non-profile callers (e.g. parental-PIN
/// dialogs that are not tied to a specific profile).
// FE-PM-03
const _kNoProfileId = '__global__';

/// A reusable PIN input dialog for parental controls.
///
/// Shows a 4-digit PIN input with optional verification callback.
/// After [kPinMaxAttempts] consecutive wrong attempts the dialog
/// locks for 5 minutes and displays a live countdown.  The lockout
/// persists across dialog open/close via [pinLockoutProvider].
///
/// Pass [profileId] to scope the lockout to a specific profile so
/// that wrong attempts on one profile do not affect another.
///
/// FE-PS-05: When [showBiometric] is true and biometric auth is
/// enabled for the profile, shows a fingerprint icon button. On tap
/// it attempts biometric authentication (via `local_auth` — see TODO).
// FE-PM-03
class PinInputDialog extends ConsumerStatefulWidget {
  const PinInputDialog({
    required this.title,
    this.subtitle,
    this.onVerify,
    this.onSubmit,
    this.confirmMode = false,
    // FE-PM-03: per-profile lockout scoping.
    this.profileId,
    // FE-PS-05: biometric auth toggle.
    this.showBiometric = false,
    super.key,
  });

  /// Dialog title (e.g., "Enter PIN", "Set New PIN").
  final String title;

  /// Optional subtitle/description.
  final String? subtitle;

  /// Async verification callback. Returns true if PIN is valid.
  /// Used for verifying existing PINs.
  final Future<bool> Function(String pin)? onVerify;

  /// Submit callback. Called with the entered PIN.
  /// Used for setting new PINs.
  final void Function(String pin)? onSubmit;

  /// If true, requires PIN to be entered twice for confirmation.
  final bool confirmMode;

  /// Profile ID to scope the lockout to. When null the lockout is
  /// shared across all non-profile callers (legacy behaviour).
  // FE-PM-03
  final String? profileId;

  /// FE-PS-05: When true, shows a biometric (fingerprint) icon button
  /// next to the PIN fields. Biometric is only shown when the user
  /// has enabled it for this profile via [biometricPreferenceProvider].
  final bool showBiometric;

  /// Shows the PIN input dialog.
  ///
  /// Returns true if PIN was verified/submitted successfully,
  /// false otherwise.
  ///
  /// Pass [profileId] to scope the wrong-attempt lockout to a
  /// specific profile (FE-PM-03).
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Future<bool> Function(String pin)? onVerify,
    void Function(String pin)? onSubmit,
    bool confirmMode = false,
    // FE-PM-03: per-profile lockout.
    String? profileId,
    // FE-PS-05: biometric shortcut.
    bool showBiometric = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => PinInputDialog(
            title: title,
            subtitle: subtitle,
            onVerify: onVerify,
            onSubmit: onSubmit,
            confirmMode: confirmMode,
            profileId: profileId,
            showBiometric: showBiometric,
          ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends ConsumerState<PinInputDialog> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;
  bool _isVerifying = false;
  bool _isConfirmPhase = false;
  String? _firstPin;
  // FE-PS-05: tracks whether biometric attempt is in progress.
  bool _isBiometricLoading = false;

  // FE-PM-03: resolved profile key for lockout provider calls.
  String get _profileKey => widget.profileId ?? _kNoProfileId;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);

    if (value.isNotEmpty && index < 3) {
      // Move to next field.
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace.
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-submit when all 4 digits entered.
    if (_currentPin.length == 4) {
      _submit();
    }
  }

  Future<void> _submit() async {
    // FE-PM-03: check per-profile lockout before allowing entry.
    final lockout = ref.read(pinLockoutProvider);
    if (lockout.isLockedFor(_profileKey)) return;

    final pin = _currentPin;
    if (pin.length != 4) {
      setState(() => _error = 'Enter all 4 digits');
      return;
    }

    // Handle confirm mode (setting new PIN).
    if (widget.confirmMode) {
      if (!_isConfirmPhase) {
        // First entry — save and ask for confirmation.
        _firstPin = pin;
        setState(() => _isConfirmPhase = true);
        _clearFields();
        return;
      } else {
        // Second entry — check match.
        if (pin != _firstPin) {
          setState(() {
            _error = 'PINs do not match';
            _isConfirmPhase = false;
            _firstPin = null;
          });
          _clearFields();
          return;
        }
        // PINs match — reset lockout and submit.
        // FE-PM-03: record success for this profile.
        ref
            .read(pinLockoutProvider.notifier)
            .recordSuccess(profileId: _profileKey);
        widget.onSubmit?.call(pin);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
    }

    // Handle verification mode.
    if (widget.onVerify != null) {
      setState(() => _isVerifying = true);

      try {
        final isValid = await widget.onVerify!(pin);
        if (!mounted) return;

        if (isValid) {
          // FE-PM-03: record success resets the per-profile counter.
          ref
              .read(pinLockoutProvider.notifier)
              .recordSuccess(profileId: _profileKey);
          Navigator.of(context).pop(true);
        } else {
          // FE-PM-03: record failure, triggers lockout at kPinMaxAttempts.
          ref
              .read(pinLockoutProvider.notifier)
              .recordFailure(profileId: _profileKey);
          setState(() {
            _error = 'Incorrect PIN';
            _isVerifying = false;
          });
          _clearFields();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Verification failed';
          _isVerifying = false;
        });
        _clearFields();
      }
      return;
    }

    // Simple submit (no verification).
    // FE-PM-03: record success for this profile.
    ref.read(pinLockoutProvider.notifier).recordSuccess(profileId: _profileKey);
    widget.onSubmit?.call(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _clearFields() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _tryBiometric() async {
    if (_isBiometricLoading || _isVerifying) return;

    setState(() => _isBiometricLoading = true);

    final token = await ref
        .read(biometricPreferenceProvider.notifier)
        .attemptBiometric('Access ${widget.profileId} profile');

    if (mounted) {
      setState(() => _isBiometricLoading = false);
      if (token != null) {
        // Success — treat as verified
        ref
            .read(pinLockoutProvider.notifier)
            .recordSuccess(profileId: _profileKey);
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Biometric authentication failed or canceled');
      }
    }
  }

  /// Formats [Duration] as `M:SS` for the countdown display.
  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // FE-PM-03: Watch lockout state — rebuilds every second while locked.
    final lockout = ref.watch(pinLockoutProvider);
    final isLocked = lockout.isLockedFor(_profileKey);
    final remaining = lockout.remainingFor(_profileKey);

    String displayTitle = widget.title;
    if (widget.confirmMode && _isConfirmPhase) {
      displayTitle = 'Confirm PIN';
    }

    return AlertDialog(
      title: Text(displayTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLocked) ...[
            // FE-PM-03: Lockout countdown display.
            Padding(
              padding: const EdgeInsets.only(bottom: CrispySpacing.md),
              child: Column(
                children: [
                  Icon(Icons.lock_clock, size: 36, color: colorScheme.error),
                  const SizedBox(height: CrispySpacing.sm),
                  Text(
                    'Too many incorrect attempts.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CrispySpacing.xs),
                  // FE-PM-03: live countdown timer updates every second.
                  Text(
                    'Try again in ${_formatCountdown(remaining)}',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            if (widget.subtitle != null && !_isConfirmPhase)
              Padding(
                padding: const EdgeInsets.only(bottom: CrispySpacing.md),
                child: Text(
                  widget.subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isConfirmPhase)
              Padding(
                padding: const EdgeInsets.only(bottom: CrispySpacing.md),
                child: Text(
                  'Enter the same PIN again to confirm',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FE-PS-05: biometric icon button to the left of PIN fields.
                if (widget.showBiometric &&
                    widget.profileId != null &&
                    (ref.watch(biometricPreferenceProvider).value?[widget
                            .profileId!] ??
                        false))
                  Padding(
                    padding: const EdgeInsets.only(right: CrispySpacing.sm),
                    child:
                        _isBiometricLoading
                            ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Tooltip(
                              message: 'Use fingerprint or face',
                              child: IconButton(
                                icon: const Icon(Icons.fingerprint),
                                onPressed: _isVerifying ? null : _tryBiometric,
                                color: colorScheme.primary,
                                iconSize: 36,
                              ),
                            ),
                  ),
                // PIN digit fields.
                ...List.generate(4, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: i > 0 ? CrispySpacing.sm : 0,
                    ),
                    child: SizedBox(
                      width: 48,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        obscureText: true,
                        enabled: !_isVerifying && !isLocked,
                        autofocus: i == 0,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        style: textTheme.headlineMedium,
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    ),
                  );
                }),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.sm),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            if (_isVerifying)
              const Padding(
                padding: EdgeInsets.only(top: CrispySpacing.md),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!isLocked)
          FilledButton(
            onPressed: _isVerifying ? null : _submit,
            child: Text(_isConfirmPhase ? 'Confirm' : 'Submit'),
          ),
      ],
    );
  }
}
