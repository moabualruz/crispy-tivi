import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';
import 'tls_toggle_widget.dart';

/// Key used to persist the global TLS default setting.
const kTlsAcceptSelfSignedDefaultKey = 'tls_accept_self_signed_default';

/// Network security settings section with global TLS toggle.
///
/// Shows a [TlsToggleWidget] that controls the global default
/// for accepting self-signed TLS certificates. This value is
/// persisted via [CacheService] to the Rust settings store.
class NetworkSecuritySection extends ConsumerStatefulWidget {
  const NetworkSecuritySection({super.key});

  @override
  ConsumerState<NetworkSecuritySection> createState() =>
      _NetworkSecuritySectionState();
}

class _NetworkSecuritySectionState
    extends ConsumerState<NetworkSecuritySection> {
  bool _acceptSelfSigned = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final cache = ref.read(cacheServiceProvider);
    final raw = await cache.getSetting(kTlsAcceptSelfSignedDefaultKey);
    if (mounted) {
      setState(() {
        _acceptSelfSigned = raw == 'true';
        _loaded = true;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    final cache = ref.read(cacheServiceProvider);
    await cache.setSetting(kTlsAcceptSelfSignedDefaultKey, value.toString());
    if (mounted) {
      setState(() => _acceptSelfSigned = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Network Security',
          icon: Icons.security,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            TlsToggleWidget(value: _acceptSelfSigned, onChanged: _onChanged),
          ],
        ),
      ],
    );
  }
}
