import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/playlist_source.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/async_filled_button.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../settings/presentation/widgets/source_form_fields.dart';
import '../../../settings/presentation/widgets/source_verify_utils.dart';
import '../providers/onboarding_notifier.dart';

/// Third step of the onboarding wizard — source configuration form.
///
/// Renders the appropriate form fields for the selected source type
/// (M3U, Xtream Codes, or Stalker Portal) using the shared field
/// widgets from `source_form_fields.dart`. Validates input and calls
/// [OnboardingNotifier.submitSource] with the built [PlaylistSource].
class OnboardingFormStep extends ConsumerStatefulWidget {
  const OnboardingFormStep({super.key});

  @override
  ConsumerState<OnboardingFormStep> createState() => _OnboardingFormStepState();
}

class _OnboardingFormStepState extends ConsumerState<OnboardingFormStep> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _macCtrl = TextEditingController();

  String? _validationError;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // Listen for source type changes so controllers reset when the
    // user goes back and picks a different source type.
    ref.listenManual(onboardingProvider.select((s) => s.sourceType), (
      previous,
      next,
    ) {
      if (previous != null && previous != next) {
        _clearControllers();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _nameCtrl.clear();
    _urlCtrl.clear();
    _userCtrl.clear();
    _passCtrl.clear();
    _macCtrl.clear();
    if (mounted) setState(() => _validationError = null);
  }

  String _defaultName(PlaylistSourceType type) {
    return switch (type) {
      PlaylistSourceType.m3u => 'My Playlist',
      PlaylistSourceType.xtream => 'My IPTV Provider',
      PlaylistSourceType.stalkerPortal => 'My Portal',
      _ => 'My Source',
    };
  }

  String _displayName(PlaylistSourceType type) {
    return switch (type) {
      PlaylistSourceType.m3u => 'M3U Playlist',
      PlaylistSourceType.xtream => 'Xtream Codes',
      PlaylistSourceType.stalkerPortal => 'Stalker Portal',
      _ => 'Source',
    };
  }

  Future<void> _submit(PlaylistSourceType sourceType) async {
    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    // Validate required URL field.
    if (url.isEmpty) {
      setState(() => _validationError = 'URL is required.');
      return;
    }

    // Validate Xtream credentials.
    if (sourceType == PlaylistSourceType.xtream) {
      if (_userCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
        setState(
          () => _validationError = 'Username and password are required.',
        );
        return;
      }
    }

    // Validate Stalker MAC address.
    if (sourceType == PlaylistSourceType.stalkerPortal) {
      final mac = _macCtrl.text.trim().toUpperCase();
      if (mac.isEmpty) {
        setState(() => _validationError = 'MAC address is required.');
        return;
      }
      if (!kMacAddressRegExp.hasMatch(mac)) {
        setState(
          () =>
              _validationError =
                  'Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.',
        );
        return;
      }
    }

    setState(() {
      _validationError = null;
      _isVerifying = true;
    });

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    // Verify server connectivity before saving.
    final verifyError = await verifySourceConnectivity(
      ref,
      sourceType,
      url,
      username: user,
      password: pass,
      macAddress:
          sourceType == PlaylistSourceType.stalkerPortal
              ? _macCtrl.text.trim().toUpperCase()
              : null,
    );

    if (!mounted) return;
    if (verifyError != null) {
      setState(() {
        _isVerifying = false;
        _validationError = verifyError;
      });
      return;
    }

    setState(() => _isVerifying = false);

    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name.isEmpty ? _defaultName(sourceType) : name,
      url: url,
      type: sourceType,
      username: sourceType == PlaylistSourceType.xtream ? user : null,
      password: sourceType == PlaylistSourceType.xtream ? pass : null,
      epgUrl:
          sourceType == PlaylistSourceType.xtream
              ? PlaylistSource.buildXtreamEpgUrl(url, user, pass)
              : null,
      macAddress:
          sourceType == PlaylistSourceType.stalkerPortal
              ? _macCtrl.text.trim().toUpperCase()
              : null,
    );

    ref.read(onboardingProvider.notifier).submitSource(source);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final sourceType = state.sourceType;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (sourceType == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configure ${_displayName(sourceType)}',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CrispySpacing.lg),
          switch (sourceType) {
            PlaylistSourceType.m3u => M3uFormFields(
              nameCtrl: _nameCtrl,
              urlCtrl: _urlCtrl,
            ),
            PlaylistSourceType.xtream => XtreamFormFields(
              nameCtrl: _nameCtrl,
              urlCtrl: _urlCtrl,
              userCtrl: _userCtrl,
              passCtrl: _passCtrl,
            ),
            PlaylistSourceType.stalkerPortal => StalkerFormFields(
              nameCtrl: _nameCtrl,
              urlCtrl: _urlCtrl,
              macCtrl: _macCtrl,
            ),
            _ => const SizedBox.shrink(),
          },
          if (_validationError != null) ...[
            const SizedBox(height: CrispySpacing.sm),
            Text(
              _validationError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: CrispySpacing.lg),
          Semantics(
            button: true,
            label: 'Connect to server',
            child: FocusWrapper(
              autofocus: false,
              onSelect: _isVerifying ? null : () => _submit(sourceType),
              child: AsyncFilledButton(
                isLoading: _isVerifying,
                label: 'Connect',
                onPressed: () => _submit(sourceType),
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Center(
            child: Semantics(
              button: true,
              label: 'Go back to previous step',
              child: TextButton.icon(
                onPressed: () => ref.read(onboardingProvider.notifier).goBack(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
