import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../providers/settings_service_providers.dart';
import 'settings_shared_widgets.dart';

// FE-S-11: Network Diagnostics — tile + bottom sheet with live checks.

// ── State ────────────────────────────────────────────────────────

class _DiagState {
  const _DiagState({required this.results, required this.running});

  final List<DiagResult> results;
  final bool running;

  static _DiagState initial() => _DiagState(
    results: [
      const DiagResult(label: 'Connection Type', status: DiagStatus.pending),
      const DiagResult(label: 'DNS Resolution', status: DiagStatus.pending),
      const DiagResult(label: 'Latency', status: DiagStatus.pending),
      const DiagResult(label: 'Download Speed', status: DiagStatus.pending),
    ],
    running: false,
  );

  _DiagState copyWith({List<DiagResult>? results, bool? running}) => _DiagState(
    results: results ?? this.results,
    running: running ?? this.running,
  );
}

// ── Settings tile (shown inline in SettingsScreen) ──────────────

/// Network Diagnostics settings tile.
///
/// Tapping opens [NetworkDiagnosticsSheet] as a modal bottom sheet.
class NetworkDiagnosticsTile extends StatelessWidget {
  const NetworkDiagnosticsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Network',
          icon: Icons.network_check,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Network Diagnostics'),
              subtitle: const Text('Test connection type, DNS, and latency'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDiagnostics(context),
            ),
          ],
        ),
      ],
    );
  }

  void _openDiagnostics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NetworkDiagnosticsSheet(),
    );
  }
}

// ── Bottom sheet ────────────────────────────────────────────────

/// Full Network Diagnostics bottom sheet.
///
/// Runs four checks sequentially:
/// 1. Connection type (WiFi / Ethernet / Mobile / None)
/// 2. DNS resolution (`dns.google`)
/// 3. Round-trip latency to `1.1.1.1:443`
/// 4. Download speed estimate via Cloudflare speed.cloudflare.com
///
/// Results are shown as status cards with pass/warn/fail indicators.
class NetworkDiagnosticsSheet extends ConsumerStatefulWidget {
  const NetworkDiagnosticsSheet({super.key});

  @override
  ConsumerState<NetworkDiagnosticsSheet> createState() =>
      _NetworkDiagnosticsSheetState();
}

class _NetworkDiagnosticsSheetState
    extends ConsumerState<NetworkDiagnosticsSheet> {
  _DiagState _state = _DiagState.initial();
  final _service = NetworkDiagnosticsService();

  @override
  void initState() {
    super.initState();
    // Auto-run on open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  // ── Orchestrator ─────────────────────────────────────────────

  Future<void> _runAll() async {
    setState(() => _state = _DiagState.initial().copyWith(running: true));

    final results = List<DiagResult>.from(_state.results);

    // 1. Connection type
    results[0] = const DiagResult(
      label: 'Connection Type',
      status: DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[0] = await _service.checkConnectionType();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 2. DNS
    results[1] = const DiagResult(
      label: 'DNS Resolution',
      status: DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[1] = await _service.checkDns();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 3. Latency
    results[2] = const DiagResult(label: 'Latency', status: DiagStatus.running);
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[2] = await _service.checkLatency();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 4. Download speed
    results[3] = const DiagResult(
      label: 'Download Speed',
      status: DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[3] = await _service.checkDownloadSpeed();
    setState(
      () =>
          _state = _state.copyWith(results: List.from(results), running: false),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder:
          (context, scroll) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: CrispySpacing.sm,
                    ),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                    ),
                  ),
                ),
                // Header row
                Row(
                  children: [
                    Icon(Icons.network_check, color: colorScheme.primary),
                    const SizedBox(width: CrispySpacing.sm),
                    Expanded(
                      child: Text(
                        'Network Diagnostics',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_state.running)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Run again',
                        onPressed: _runAll,
                      ),
                  ],
                ),
                const SizedBox(height: CrispySpacing.md),
                // Result cards
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children:
                        _state.results
                            .map((r) => _DiagCard(result: r))
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

// ── Individual result card ───────────────────────────────────────

class _DiagCard extends StatelessWidget {
  const _DiagCard({required this.result});

  final DiagResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (iconData, iconColor, bgColor) = switch (result.status) {
      DiagStatus.pending => (
        Icons.hourglass_empty,
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainer,
      ),
      DiagStatus.running => (
        Icons.sync,
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      DiagStatus.pass => (
        Icons.check_circle_outline,
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      DiagStatus.warn => (
        Icons.warning_amber_outlined,
        colorScheme.tertiary,
        colorScheme.tertiaryContainer,
      ),
      DiagStatus.fail => (
        Icons.error_outline,
        colorScheme.error,
        colorScheme.errorContainer,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
              ),
              child:
                  result.status == DiagStatus.running
                      ? const Padding(
                        padding: EdgeInsets.all(CrispySpacing.sm),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: CrispySpacing.md),
            // Label + detail
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (result.detail != null) ...[
                    const SizedBox(height: CrispySpacing.xxs),
                    Text(
                      result.detail!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Value chip
            if (result.value != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                  vertical: CrispySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
                child: Text(
                  result.value!,
                  style: textTheme.labelMedium?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
