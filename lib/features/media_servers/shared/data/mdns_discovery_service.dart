// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A server discovered via mDNS/Bonjour on the local network.
///
/// MSB-FE-03: Discovery stub. Fields match what a real mDNS record
/// would provide for `_jellyfin._tcp` and `_emby._tcp` service types.
class DiscoveredServer {
  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    required this.serviceType,
    this.path = '/',
  });

  /// Human-readable server name advertised in the mDNS TXT record.
  final String name;

  /// Resolved hostname or IP address.
  final String host;

  /// TCP port the server listens on.
  final int port;

  /// mDNS service type: `_jellyfin._tcp` or `_emby._tcp`.
  final String serviceType;

  /// Optional base path (e.g. `/jellyfin` for sub-path installs).
  final String path;

  /// Reconstructed base URL for this server.
  String get url => 'http://$host:$port$path';

  /// Whether this is a Jellyfin server.
  bool get isJellyfin => serviceType.contains('jellyfin');

  /// Whether this is an Emby server.
  bool get isEmby => serviceType.contains('emby');

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && host == other.host && port == other.port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'DiscoveredServer($name @ $url [$serviceType])';
}

/// Current state of the mDNS discovery scan.
enum MdnsDiscoveryStatus {
  /// Discovery has not started or is idle.
  idle,

  /// Actively scanning for services.
  scanning,

  /// Scan completed (may have found servers or none).
  done,
}

/// State for [MdnsDiscoveryNotifier].
class MdnsDiscoveryState {
  const MdnsDiscoveryState({
    this.status = MdnsDiscoveryStatus.idle,
    this.servers = const [],
  });

  final MdnsDiscoveryStatus status;

  /// Servers found so far in the current scan.
  final List<DiscoveredServer> servers;

  bool get isScanning => status == MdnsDiscoveryStatus.scanning;

  MdnsDiscoveryState copyWith({
    MdnsDiscoveryStatus? status,
    List<DiscoveredServer>? servers,
  }) => MdnsDiscoveryState(
    status: status ?? this.status,
    servers: servers ?? this.servers,
  );
}

/// MSB-FE-03: Notifier that manages mDNS/Bonjour discovery.
///
/// **STUB IMPLEMENTATION** — the `multicast_dns` package is not yet
/// in pubspec.yaml. When it is added, replace [_scanStub] with real
/// mDNS logic using:
///
/// ```dart
/// import 'package:multicast_dns/multicast_dns.dart';
///
/// final client = MDnsClient();
/// await client.start();
/// await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
///   ResourceRecordQuery.serverPointer('_jellyfin._tcp.local'),
/// )) {
///   // Resolve SRV + A records to build DiscoveredServer.
/// }
/// await client.stop();
/// ```
///
/// Service types to scan:
/// - `_jellyfin._tcp.local`
/// - `_emby._tcp.local`
class MdnsDiscoveryNotifier extends Notifier<MdnsDiscoveryState> {
  @override
  MdnsDiscoveryState build() => const MdnsDiscoveryState();

  /// Starts an mDNS scan. Clears previous results first.
  ///
  /// Currently calls [_scanStub] — replace with real mDNS when
  /// the `multicast_dns` package is available.
  Future<void> startScan() async {
    if (state.isScanning) return;

    state = state.copyWith(status: MdnsDiscoveryStatus.scanning, servers: []);

    try {
      // TODO(msb-fe-03): Replace stub with real multicast_dns scan.
      // See class doc-comment for the integration pattern.
      final discovered = await _scanStub();
      state = state.copyWith(
        status: MdnsDiscoveryStatus.done,
        servers: discovered,
      );
    } catch (e) {
      print('[mDNS] Scan error: $e');
      state = state.copyWith(status: MdnsDiscoveryStatus.done);
    }
  }

  /// Resets discovery state to idle.
  void reset() => state = const MdnsDiscoveryState();

  /// **STUB**: simulates a short scan delay and returns no servers.
  ///
  /// In real usage this would use `package:multicast_dns` to send
  /// mDNS PTR queries and collect SRV/A responses from the LAN.
  Future<List<DiscoveredServer>> _scanStub() async {
    // Simulate ~2 second network scan.
    await Future<void>.delayed(const Duration(seconds: 2));
    // Return empty list — real servers will be discovered via mDNS.
    return [];
  }
}

/// Provider for [MdnsDiscoveryNotifier].
///
/// MSB-FE-03: Watch this from the UI to render discovered servers
/// and trigger scans via [MdnsDiscoveryNotifier.startScan].
final mdnsDiscoveryProvider =
    NotifierProvider<MdnsDiscoveryNotifier, MdnsDiscoveryState>(
      MdnsDiscoveryNotifier.new,
    );
