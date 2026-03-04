import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'cast_message.dart';

/// Native implementation using mDNS discovery and Cast V2 protocol.
///
/// Provides full Chromecast support for native platforms
/// (Android, iOS, Windows, Linux, macOS).
class CastHelper {
  SecureSocket? _socket;
  final List<CastDeviceInfo> _devices = [];
  bool _isDiscovering = false;
  MDnsClient? _mdnsClient;

  // Cast session state
  String? _transportId;
  int _requestId = 0;
  int? _mediaSessionId;
  Timer? _heartbeatTimer;
  final _senderId = 'sender-0';
  final _receiverId = 'receiver-0';
  final _buffer = BytesBuilder();
  StreamSubscription<Uint8List>? _socketSubscription;

  /// Starts discovering Cast devices on the local network.
  ///
  /// Uses mDNS to find devices advertising `_googlecast._tcp`.
  /// Calls [onDevices] each time a new device is found.
  Future<void> startDiscovery(
    void Function(List<CastDeviceInfo>) onDevices,
  ) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _devices.clear();

    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start();

      // Query for Chromecast devices
      await for (final ptr in _mdnsClient!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
      )) {
        if (!_isDiscovering) break;

        // Resolve the service to get host and port
        await for (final srv in _mdnsClient!.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          // Get the IP address
          await for (final ip in _mdnsClient!.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            final device = CastDeviceInfo(
              name: _extractDeviceName(ptr.domainName),
              host: ip.address.address,
              port: srv.port,
            );

            // Avoid duplicates
            if (!_devices.any((d) => d.host == device.host)) {
              _devices.add(device);
              onDevices(List.unmodifiable(_devices));
            }
            break; // Take first IP
          }
          break; // Take first service record
        }
      }
    } catch (e) {
      debugPrint('Cast discovery error: $e');
      rethrow;
    }
  }

  /// Extracts device name from mDNS domain name.
  String _extractDeviceName(String domainName) {
    // Format: "Chromecast-xxx._googlecast._tcp.local"
    final parts = domainName.split('._googlecast');
    if (parts.isNotEmpty) {
      return parts.first.replaceAll('-', ' ');
    }
    return 'Cast Device';
  }

  /// Stops device discovery.
  void stopDiscovery() {
    _isDiscovering = false;
    _mdnsClient?.stop();
    _mdnsClient = null;
  }

  /// Connects to a Cast device and establishes a session.
  ///
  /// Implements full Cast V2 protocol:
  /// 1. TLS connection to port 8009
  /// 2. CONNECT message to receiver
  /// 3. Heartbeat management
  /// 4. Launch Default Media Receiver
  Future<bool> connect(String host, int port) async {
    try {
      // Cast devices use TLS on port 8009
      _socket = await SecureSocket.connect(
        host,
        port,
        onBadCertificate: (_) => true, // Chromecast uses self-signed certs
        timeout: const Duration(seconds: 10),
      );

      debugPrint('Cast: Connected to $host:$port');

      // Set up message listener
      _socketSubscription = _socket!.listen(
        _onData,
        onError: (e) => debugPrint('Cast socket error: $e'),
        onDone: _onDisconnect,
      );

      // Send CONNECT to receiver
      await _sendConnect(_receiverId);

      // Start heartbeat
      _startHeartbeat();

      // Launch Default Media Receiver app
      await _launchApp();

      return true;
    } catch (e) {
      debugPrint('Cast connect error: $e');
      _cleanup();
      return false;
    }
  }

  /// Sends a CONNECT message to establish a virtual connection.
  Future<void> _sendConnect(String destinationId) async {
    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: destinationId,
      namespace: CastNamespaces.connection,
      payloadType: PayloadType.STRING,
      payloadUtf8: '{"type":"CONNECT"}',
    );
    _sendMessage(message);
  }

  /// Sends a CLOSE message to end a virtual connection.
  void _sendClose(String destinationId) {
    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: destinationId,
      namespace: CastNamespaces.connection,
      payloadType: PayloadType.STRING,
      payloadUtf8: '{"type":"CLOSE"}',
    );
    _sendMessage(message);
  }

  /// Starts the heartbeat timer (sends PING every 5 seconds).
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sendPing(),
    );
  }

  /// Sends a PING message on the heartbeat namespace.
  void _sendPing() {
    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: _receiverId,
      namespace: CastNamespaces.heartbeat,
      payloadType: PayloadType.STRING,
      payloadUtf8: '{"type":"PING"}',
    );
    _sendMessage(message);
  }

  /// Launches the Default Media Receiver app.
  Future<void> _launchApp() async {
    _requestId++;
    final payload = jsonEncode({
      'type': 'LAUNCH',
      'appId': kDefaultMediaReceiverAppId,
      'requestId': _requestId,
    });

    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: _receiverId,
      namespace: CastNamespaces.receiver,
      payloadType: PayloadType.STRING,
      payloadUtf8: payload,
    );
    _sendMessage(message);
  }

  /// Loads a media URL onto the connected Cast device.
  Future<bool> loadMedia(String url, String title) async {
    if (_socket == null) return false;
    if (_transportId == null) {
      debugPrint('Cast: No transport ID, waiting for app launch...');
      // Wait a bit for the app to launch and provide transport ID
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_transportId == null) {
        debugPrint('Cast: Still no transport ID, trying to load anyway');
      }
    }

    try {
      final destination = _transportId ?? _receiverId;

      // Connect to the media receiver transport
      if (_transportId != null) {
        await _sendConnect(_transportId!);
      }

      _requestId++;
      final payload = jsonEncode({
        'type': 'LOAD',
        'requestId': _requestId,
        'media': {
          'contentId': url,
          'contentType': _guessContentType(url),
          'streamType': 'BUFFERED',
          'metadata': {
            'type': 0, // Generic
            'metadataType': 0,
            'title': title,
          },
        },
        'autoplay': true,
        'currentTime': 0,
      });

      final message = CastMessage(
        protocolVersion: 0,
        sourceId: _senderId,
        destinationId: destination,
        namespace: CastNamespaces.media,
        payloadType: PayloadType.STRING,
        payloadUtf8: payload,
      );
      _sendMessage(message);

      debugPrint('Cast: Loading media "$title"');
      return true;
    } catch (e) {
      debugPrint('Cast loadMedia error: $e');
      return false;
    }
  }

  /// Guesses the content type from URL extension.
  String _guessContentType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('m3u8')) {
      return 'application/x-mpegURL';
    }
    if (lower.contains('.mpd')) {
      return 'application/dash+xml';
    }
    if (lower.contains('.mp4')) {
      return 'video/mp4';
    }
    if (lower.contains('.mkv')) {
      return 'video/x-matroska';
    }
    if (lower.contains('.ts')) {
      return 'video/mp2t';
    }
    // Default to HLS for live streams
    return 'application/x-mpegURL';
  }

  /// Pauses playback on the Cast device.
  void pause() {
    _sendMediaCommand('PAUSE');
  }

  /// Resumes playback on the Cast device.
  void resume() {
    _sendMediaCommand('PLAY');
  }

  /// Stops playback on the Cast device.
  void stop() {
    _sendMediaCommand('STOP');
  }

  /// Sends a media control command.
  void _sendMediaCommand(String type) {
    if (_socket == null) return;

    final destination = _transportId ?? _receiverId;
    _requestId++;

    final payload = <String, dynamic>{'type': type, 'requestId': _requestId};

    // Include mediaSessionId if we have one
    if (_mediaSessionId != null) {
      payload['mediaSessionId'] = _mediaSessionId;
    }

    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: destination,
      namespace: CastNamespaces.media,
      payloadType: PayloadType.STRING,
      payloadUtf8: jsonEncode(payload),
    );
    _sendMessage(message);
  }

  /// Sends a CastMessage over the socket.
  void _sendMessage(CastMessage message) {
    if (_socket == null) return;
    try {
      final encoded = encodeCastMessage(message);
      _socket!.add(encoded);
    } catch (e) {
      debugPrint('Cast send error: $e');
    }
  }

  /// Handles incoming data from the socket.
  void _onData(Uint8List data) {
    _buffer.add(data);

    // Process complete messages from buffer
    while (_buffer.length >= 4) {
      final bytes = _buffer.toBytes();
      final messageLength = decodeCastMessageLength(bytes);
      if (messageLength == null) break;

      final totalLength = 4 + messageLength;
      if (bytes.length < totalLength) break;

      // Extract and process the message
      final messageBytes = bytes.sublist(4, totalLength);
      _processMessage(messageBytes);

      // Remove processed bytes from buffer
      _buffer.clear();
      if (bytes.length > totalLength) {
        _buffer.add(bytes.sublist(totalLength));
      }
    }
  }

  /// Processes a received CastMessage.
  void _processMessage(List<int> bytes) {
    try {
      final message = CastMessage.fromBuffer(bytes);
      final namespace = message.namespace;
      final payloadStr = message.payloadUtf8;

      if (payloadStr.isEmpty) return;

      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = payload['type'] as String?;

      debugPrint('Cast: Received $type on $namespace');

      // Handle heartbeat PING (respond with PONG)
      if (namespace == CastNamespaces.heartbeat && type == 'PING') {
        _sendPong();
        return;
      }

      // Handle receiver status (get transport ID)
      if (namespace == CastNamespaces.receiver && type == 'RECEIVER_STATUS') {
        _handleReceiverStatus(payload);
        return;
      }

      // Handle media status (get mediaSessionId)
      if (namespace == CastNamespaces.media && type == 'MEDIA_STATUS') {
        _handleMediaStatus(payload);
        return;
      }
    } catch (e) {
      debugPrint('Cast: Error processing message: $e');
    }
  }

  /// Sends a PONG response to a PING.
  void _sendPong() {
    final message = CastMessage(
      protocolVersion: 0,
      sourceId: _senderId,
      destinationId: _receiverId,
      namespace: CastNamespaces.heartbeat,
      payloadType: PayloadType.STRING,
      payloadUtf8: '{"type":"PONG"}',
    );
    _sendMessage(message);
  }

  /// Handles RECEIVER_STATUS to extract transport ID.
  void _handleReceiverStatus(Map<String, dynamic> payload) {
    final status = payload['status'] as Map<String, dynamic>?;
    if (status == null) return;

    final applications = status['applications'] as List<dynamic>?;
    if (applications == null || applications.isEmpty) return;

    final app = applications.first as Map<String, dynamic>;
    final transportId = app['transportId'] as String?;

    if (transportId != null && transportId != _transportId) {
      debugPrint('Cast: Got transport ID: $transportId');
      _transportId = transportId;
    }
  }

  /// Handles MEDIA_STATUS to extract mediaSessionId.
  void _handleMediaStatus(Map<String, dynamic> payload) {
    final statusList = payload['status'] as List<dynamic>?;
    if (statusList == null || statusList.isEmpty) return;

    final status = statusList.first as Map<String, dynamic>;
    final mediaSessionId = status['mediaSessionId'] as int?;

    if (mediaSessionId != null) {
      _mediaSessionId = mediaSessionId;
      debugPrint('Cast: Got mediaSessionId: $mediaSessionId');
    }
  }

  /// Handles socket disconnection.
  void _onDisconnect() {
    debugPrint('Cast: Disconnected');
    _cleanup();
  }

  /// Disconnects from the Cast device.
  void disconnect() {
    if (_socket != null && _transportId != null) {
      _sendClose(_transportId!);
    }
    _sendClose(_receiverId);
    _cleanup();
  }

  /// Cleans up resources.
  void _cleanup() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _transportId = null;
    _mediaSessionId = null;
    _buffer.clear();
  }

  /// Whether currently connected to a Cast device.
  bool get isConnected => _socket != null;
}

/// Information about a discovered Cast device.
class CastDeviceInfo {
  const CastDeviceInfo({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Display name of the device.
  final String name;

  /// IP address or hostname.
  final String host;

  /// Port number for Cast protocol.
  final int port;
}
