import 'dart:async';
import 'dart:io';

import '../../../core/network/network_timeouts.dart';
import '../../../core/utils/format_utils.dart';

/// Status of a single diagnostic check.
enum DiagStatus { pending, running, pass, warn, fail }

/// Result of a single diagnostic check.
class DiagResult {
  const DiagResult({
    required this.label,
    required this.status,
    this.value,
    this.detail,
  });

  /// Human-readable label for the check.
  final String label;

  /// Current status of the check.
  final DiagStatus status;

  /// Short result value (e.g. "42 ms", "WiFi").
  final String? value;

  /// Longer description of the result.
  final String? detail;
}

/// Runs network diagnostic checks using platform I/O.
///
/// Lives in data layer because it uses `dart:io` (Socket,
/// InternetAddress, NetworkInterface, HttpClient).
class NetworkDiagnosticsService {
  /// Detects the connection type by inspecting network interfaces.
  Future<DiagResult> checkConnectionType() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.any,
      );

      if (interfaces.isEmpty) {
        return const DiagResult(
          label: 'Connection Type',
          status: DiagStatus.fail,
          value: 'No interfaces',
          detail: 'No network interfaces detected',
        );
      }

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

      return DiagResult(
        label: 'Connection Type',
        status: DiagStatus.pass,
        value: type,
        detail: '${interfaces.length} interface(s) found',
      );
    } catch (e) {
      return DiagResult(
        label: 'Connection Type',
        status: DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  /// Resolves `dns.google` to check DNS connectivity.
  Future<DiagResult> checkDns() async {
    const host = 'dns.google';
    try {
      final sw = Stopwatch()..start();
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(NetworkTimeouts.diagCheckTimeout);
      sw.stop();
      if (addresses.isEmpty) {
        return const DiagResult(
          label: 'DNS Resolution',
          status: DiagStatus.fail,
          value: 'No results',
          detail: 'dns.google returned no addresses',
        );
      }
      return DiagResult(
        label: 'DNS Resolution',
        status: DiagStatus.pass,
        value: '${sw.elapsedMilliseconds} ms',
        detail: addresses.first.address,
      );
    } on TimeoutException {
      return const DiagResult(
        label: 'DNS Resolution',
        status: DiagStatus.fail,
        value: 'Timeout',
        detail: 'DNS lookup timed out after 5 s',
      );
    } catch (e) {
      return DiagResult(
        label: 'DNS Resolution',
        status: DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  /// Measures TCP connect latency to 1.1.1.1:443.
  Future<DiagResult> checkLatency() async {
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
              ? DiagStatus.pass
              : ms < 300
              ? DiagStatus.warn
              : DiagStatus.fail;

      return DiagResult(
        label: 'Latency',
        status: status,
        value: '$ms ms',
        detail: 'TCP connect to $host:$port',
      );
    } on TimeoutException {
      return const DiagResult(
        label: 'Latency',
        status: DiagStatus.fail,
        value: 'Timeout',
        detail: 'Connection timed out after 5 s',
      );
    } catch (e) {
      return DiagResult(
        label: 'Latency',
        status: DiagStatus.fail,
        value: 'Error',
        detail: e.toString(),
      );
    }
  }

  /// Downloads ~1 MB from Cloudflare to estimate speed.
  Future<DiagResult> checkDownloadSpeed() async {
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
        return const DiagResult(
          label: 'Download Speed',
          status: DiagStatus.fail,
          value: 'No data',
          detail: 'Speed test returned 0 bytes',
        );
      }

      final seconds = sw.elapsedMilliseconds / 1000.0;
      final mbps = (bytes * 8) / (seconds * 1_000_000);
      final mbpsStr = mbps.toStringAsFixed(1);

      final status =
          mbps >= 5.0
              ? DiagStatus.pass
              : mbps >= 1.0
              ? DiagStatus.warn
              : DiagStatus.fail;

      return DiagResult(
        label: 'Download Speed',
        status: status,
        value: '$mbpsStr Mbps',
        detail: '${formatBytes(bytes)} in ${seconds.toStringAsFixed(1)} s',
      );
    } on TimeoutException {
      return const DiagResult(
        label: 'Download Speed',
        status: DiagStatus.fail,
        value: 'Timeout',
        detail: 'Speed test timed out after 15 s',
      );
    } catch (e) {
      return DiagResult(
        label: 'Download Speed',
        status: DiagStatus.warn,
        value: 'Unavailable',
        detail: e.toString(),
      );
    }
  }
}
