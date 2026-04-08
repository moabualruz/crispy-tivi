import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

/// Cast V2 protocol message.
///
/// This is a manually-implemented protobuf message matching the
/// `cast_channel.proto` specification used by Chromecast devices.
///
/// Fields:
/// 1. protocol_version (int32) - Always 0
/// 2. source_id (string) - Sender identifier (e.g., "sender-0")
/// 3. destination_id (string) - Receiver identifier (e.g., "receiver-0")
/// 4. namespace (string) - Message namespace (e.g., "urn:x-cast:...")
/// 5. payload_type (enum) - STRING or BINARY
/// 6. payload_utf8 (string) - JSON payload when type is STRING
/// 7. payload_binary (bytes) - Binary payload when type is BINARY
class CastMessage extends GeneratedMessage {
  CastMessage._();

  factory CastMessage({
    int? protocolVersion,
    String? sourceId,
    String? destinationId,
    String? namespace,
    PayloadType? payloadType,
    String? payloadUtf8,
    List<int>? payloadBinary,
  }) {
    final msg = CastMessage._();
    if (protocolVersion != null) msg.protocolVersion = protocolVersion;
    if (sourceId != null) msg.sourceId = sourceId;
    if (destinationId != null) msg.destinationId = destinationId;
    if (namespace != null) msg.namespace = namespace;
    if (payloadType != null) msg.payloadType = payloadType;
    if (payloadUtf8 != null) msg.payloadUtf8 = payloadUtf8;
    if (payloadBinary != null) msg.payloadBinary = payloadBinary;
    return msg;
  }

  factory CastMessage.fromBuffer(List<int> bytes) {
    final msg = CastMessage._();
    msg.mergeFromBuffer(bytes);
    return msg;
  }

  static final BuilderInfo _i =
      BuilderInfo(
          'CastMessage',
          package: const PackageName('extensions.api.cast_channel'),
        )
        ..a<int>(
          1,
          'protocolVersion',
          PbFieldType.O3,
          protoName: 'protocol_version',
        )
        ..aOS(2, 'sourceId', protoName: 'source_id')
        ..aOS(3, 'destinationId', protoName: 'destination_id')
        ..aOS(4, 'namespace')
        ..e<PayloadType>(
          5,
          'payloadType',
          PbFieldType.OE,
          protoName: 'payload_type',
          defaultOrMaker: PayloadType.STRING,
          valueOf: PayloadType.valueOf,
          enumValues: PayloadType.values,
        )
        ..aOS(6, 'payloadUtf8', protoName: 'payload_utf8')
        ..a<List<int>>(
          7,
          'payloadBinary',
          PbFieldType.OY,
          protoName: 'payload_binary',
        )
        ..hasRequiredFields = false;

  @override
  BuilderInfo get info_ => _i;

  @override
  CastMessage createEmptyInstance() => CastMessage._();

  @override
  CastMessage clone() => CastMessage._()..mergeFromMessage(this);

  // Field accessors

  int get protocolVersion => $_getIZ(0);
  set protocolVersion(int v) => $_setSignedInt32(0, v);
  bool hasProtocolVersion() => $_has(0);

  String get sourceId => $_getSZ(1);
  set sourceId(String v) => $_setString(1, v);
  bool hasSourceId() => $_has(1);

  String get destinationId => $_getSZ(2);
  set destinationId(String v) => $_setString(2, v);
  bool hasDestinationId() => $_has(2);

  String get namespace => $_getSZ(3);
  set namespace(String v) => $_setString(3, v);
  bool hasNamespace() => $_has(3);

  PayloadType get payloadType => $_getN(4);
  set payloadType(PayloadType v) => setField(5, v);
  bool hasPayloadType() => $_has(4);

  String get payloadUtf8 => $_getSZ(5);
  set payloadUtf8(String v) => $_setString(5, v);
  bool hasPayloadUtf8() => $_has(5);

  List<int> get payloadBinary => $_getN(6);
  set payloadBinary(List<int> v) => setField(7, v);
  bool hasPayloadBinary() => $_has(6);
}

/// Payload type enum for CastMessage.
class PayloadType extends ProtobufEnum {
  // ignore: constant_identifier_names
  static const PayloadType STRING = PayloadType._(0, 'STRING');
  // ignore: constant_identifier_names
  static const PayloadType BINARY = PayloadType._(1, 'BINARY');

  static const List<PayloadType> values = [STRING, BINARY];

  static final Map<int, PayloadType> _byValue = ProtobufEnum.initByValue(
    values,
  );
  static PayloadType? valueOf(int value) => _byValue[value];

  const PayloadType._(super.v, super.n);
}

/// Cast protocol namespaces.
abstract final class CastNamespaces {
  /// Connection management (CONNECT, CLOSE).
  static const connection = 'urn:x-cast:com.google.cast.tp.connection';

  /// Heartbeat (PING, PONG).
  static const heartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';

  /// Receiver control (LAUNCH, STOP, GET_STATUS).
  static const receiver = 'urn:x-cast:com.google.cast.receiver';

  /// Media control (LOAD, PLAY, PAUSE, STOP, SEEK).
  static const media = 'urn:x-cast:com.google.cast.media';
}

/// Default media receiver app ID.
const kDefaultMediaReceiverAppId = 'CC1AD845';

/// Encodes a CastMessage for transmission.
///
/// Cast protocol uses 4-byte big-endian length prefix followed by
/// the protobuf-encoded message.
Uint8List encodeCastMessage(CastMessage message) {
  final messageBytes = message.writeToBuffer();
  final length = messageBytes.length;

  final result = Uint8List(4 + length);
  // Big-endian 4-byte length prefix
  result[0] = (length >> 24) & 0xFF;
  result[1] = (length >> 16) & 0xFF;
  result[2] = (length >> 8) & 0xFF;
  result[3] = length & 0xFF;
  // Message body
  result.setRange(4, 4 + length, messageBytes);

  return result;
}

/// Decodes the length prefix from a Cast protocol frame.
///
/// Returns null if there aren't enough bytes.
int? decodeCastMessageLength(List<int> bytes) {
  if (bytes.length < 4) return null;
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}
