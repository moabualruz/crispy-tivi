import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_timeouts.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

// FE-S-11: Network Diagnostics — tile + bottom sheet with live checks.
// ── Diagnostic result types ─────────────────────────────────────

enum _DiagStatus { pending, running, pass, warn, fail }

class _DiagResult {
  const _DiagResult({
    required this.label,
    required this.status,
    this.value,
    this.detail,
  });

  final String label;
  final _DiagStatus status;
  final String? value;
  final String? detail;
}

// ── State notifier ──────────────────────────────────────────────

class _DiagState {
  const _DiagState({required this.results, required this.running});

  final List<_DiagResult> results;
  final bool running;

  static _DiagState initial() => _DiagState(
    results: [
      const _DiagResult(label: 'Connection Type', status: _DiagStatus.pending),
      const _DiagResult(label: 'DNS Resolution', status: _DiagStatus.pending),
      const _DiagResult(label: 'Latency', status: _DiagStatus.pending),
      const _DiagResult(label: 'Download Speed', status: _DiagStatus.pending),
    ],
    running: false,
  );

  _DiagState copyWith({List<_DiagResult>? results, bool? running}) =>
      _DiagState(
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

  @override
  void initState() {
    super.initState();
    // Auto-run on open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  // ── Orchestrator ─────────────────────────────────────────────

  Future<void> _runAll() async {
    setState(() => _state = _DiagState.initial().copyWith(running: true));

    final results = List<_DiagResult>.from(_state.results);

    // 1. Connection type
    results[0] = const _DiagResult(
      label: 'Connection Type',
      status: _DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[0] = await _checkConnectionType();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 2. DNS
    results[1] = const _DiagResult(
      label: 'DNS Resolution',
      status: _DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[1] = await _checkDns();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 3. Latency
    results[2] = const _DiagResult(
      label: 'Latency',
      status: _DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[2] = await _checkLatency();
    setState(() => _state = _state.copyWith(results: List.from(results)));

    // 4. Download speed
    results[3] = const _DiagResult(
      label: 'Download Speed',
      status: _DiagStatus.running,
    );
    setState(() => _state = _state.copyWith(results: List.from(results)));
    results[3] = await _checkDownloadSpeed();
    setState(
      () =>
          _state = _state.copyWith(results: List.from(results), running: false),
    );
  }

  // ── Individual checks ────────────────────────────────────────

  Future<_DiagResult> _checkConnectionType() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.any,
      );

      if (interfaces.isEmpty) {
        return const _DiagResult(
          label: 'Connection Type',
          status: _DiagStatus.fail,
          value: 'No interfaces',
          detail: 'No network interfaces detected',
        );
      }

      // Heuristic: look for well-known interface name patterns.
      String? type;
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('eth') ||
            name.contains('en0') && !name.contains('wl')) {
          type = 'Ethernet';
          break;
        }
        if (name.contains('wl') ||
            name.contains('wlan') ||
            name.contains('wi')) {
          type = 'WiFi';
          break;
        }
        if (name.contains('rmnet') ||
            name.contains('ppp') ||
            name.contains('ccmni')) {
          type = 'Cellular';
          break;
        }
      }
      type ??= 'Connected (${interfaces.first.name})';

      return _DiagResult(
        label: 'Connection Type',
        status: _DiagStatus.pass,
        value: type,
        detail: '${interfaces.length} interface(s) found',
      );
    } catch (e) {
      return _DiagResult(
        label: 'Connection Type',
        status: _DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  Future<_DiagResult> _checkDns() async {
    const host = 'dns.google';
    try {
      final sw = Stopwatch()..start();
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(NetworkTimeouts.diagCheckTimeout);
      sw.stop();
      if (addresses.isEmpty) {
        return const _DiagResult(
          label: 'DNS Resolution',
          status: _DiagStatus.fail,
          value: 'No results',
          detail: 'dns.google returned no addresses',
        );
      }
      return _DiagResult(
        label: 'DNS Resolution',
        status: _DiagStatus.pass,
        value: '${sw.elapsedMilliseconds} ms',
        detail: addresses.first.address,
      );
    } on TimeoutException {
      return const _DiagResult(
        label: 'DNS Resolution',
        status: _DiagStatus.fail,
        value: 'Timeout',
        detail: 'DNS lookup timed out after 5 s',
      );
    } catch (e) {
      return _DiagResult(
        label: 'DNS Resolution',
        status: _DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  Future<_DiagResult> _checkLatency() async {
    const host = '1.1.1.1';
    const port = 443;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: NetworkTimeouts.diagCheckTimeout,
      );
      sw.stop();
      socket.destroy();

      final ms = sw.elapsedMilliseconds;
      final status =
          ms < 100
              ? _DiagStatus.pass
              : ms < 300
              ? _DiagStatus.warn
              : _DiagStatus.fail;

      return _DiagResult(
        label: 'Latency',
        status: status,
        value: '$ms ms',
        detail: 'TCP connect to $host:$port',
      );
    } on TimeoutException {
      return const _DiagResult(
        label: 'Latency',
        status: _DiagStatus.fail,
        value: 'Timeout',
        detail: 'Connection timed out after 5 s',
      );
    } catch (e) {
      return _DiagResult(
        label: 'Latency',
        status: _DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  Future<_DiagResult> _checkDownloadSpeed() async {
    // Download a ~1 MB test file from Cloudflare's speed endpoint.
    const url = 'https://speed.cloudflare.com/__down?bytes=1048576';
    try {
      final client = HttpClient();
      final sw = Stopwatch()..start();
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(NetworkTimeouts.diagDownloadTimeout);
      final response = await request.close().timeout(
        NetworkTimeouts.diagDownloadTimeout,
      );

      var bytes = 0;
      await response.forEach((chunk) => bytes += chunk.length);
      sw.stop();
      client.close();

      if (bytes == 0) {
        return const _DiagResult(
          label: 'Download Speed',
          status: _DiagStatus.fail,
          value: 'No data',
          detail: 'Speed test returned 0 bytes',
        );
      }

      final seconds = sw.elapsedMilliseconds / 1000.0;
      final mbps = (bytes * 8) / (seconds * 1_000_000);
      final mbpsStr = mbps.toStringAsFixed(1);

      final status =
          mbps >= 5.0
              ? _DiagStatus.pass
              : mbps >= 1.0
              ? _DiagStatus.warn
              : _DiagStatus.fail;

      return _DiagResult(
        label: 'Download Speed',
        status: status,
        value: '$mbpsStr Mbps',
        detail: '${formatBytes(bytes)} in ${seconds.toStringAsFixed(1)} s',
      );
    } on TimeoutException {
      return const _DiagResult(
        label: 'Download Speed',
        status: _DiagStatus.fail,
        value: 'Timeout',
        detail: 'Speed test timed out after 15 s',
      );
    } catch (e) {
      return _DiagResult(
        label: 'Download Speed',
        status: _DiagStatus.warn,
        value: 'Unavailable',
        detail: e.toString(),
      );
    }
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

  final _DiagResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (iconData, iconColor, bgColor) = switch (result.status) {
      _DiagStatus.pending => (
        Icons.hourglass_empty,
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainer,
      ),
      _DiagStatus.running => (
        Icons.sync,
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      _DiagStatus.pass => (
        Icons.check_circle_outline,
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      _DiagStatus.warn => (
        Icons.warning_amber_outlined,
        colorScheme.tertiary,
        colorScheme.tertiaryContainer,
      ),
      _DiagStatus.fail => (
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
                  result.status == _DiagStatus.running
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
