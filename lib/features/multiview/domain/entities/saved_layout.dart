import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'multiview_session.dart';

/// A persisted Multi-View layout configuration.
///
/// Stores the grid layout and channel references (not URLs) so the
/// layout can be restored even if stream URLs change.
@immutable
class SavedLayout extends Equatable {
  const SavedLayout({
    required this.id,
    required this.name,
    required this.layout,
    required this.streams,
    this.createdAt,
  });

  /// Unique identifier (UUID).
  final String id;

  /// User-defined name for this layout.
  final String name;

  /// Grid layout (2×1, 2×2, 3×3).
  final MultiViewLayout layout;

  /// Channel references for each slot (null = empty slot).
  final List<SavedStream?> streams;

  /// When this layout was created.
  final DateTime? createdAt;

  SavedLayout copyWith({
    String? id,
    String? name,
    MultiViewLayout? layout,
    List<SavedStream?>? streams,
    DateTime? createdAt,
  }) {
    return SavedLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      layout: layout ?? this.layout,
      streams: streams ?? this.streams,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, layout, streams, createdAt];
}

/// A channel reference stored in a saved layout.
///
/// Contains enough info to identify and display the channel,
/// but the actual stream URL is looked up at load time.
///
/// **Known limitation (MV-11):** [channelId] currently stores the stream
/// URL rather than a stable channel ID. This works but prevents re-linking
/// channels after a playlist refresh changes the URL. Future work should
/// store the true channel ID from [Channel.id] and resolve the URL at load
/// time via the channel provider.
@immutable
class SavedStream extends Equatable {
  const SavedStream({
    required this.channelId,
    required this.channelName,
    this.logoUrl,
  });

  /// Channel identifier for lookup.
  ///
  /// Currently stores the stream URL as a temporary identifier — see
  /// class doc for the known limitation.
  final String channelId;

  /// Channel name for display (fallback if channel not found).
  final String channelName;

  /// Channel logo URL (cached for display).
  final String? logoUrl;

  @override
  List<Object?> get props => [channelId, channelName, logoUrl];

  /// Serialize to JSON for storage.
  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
    if (logoUrl != null) 'logoUrl': logoUrl,
  };

  /// Deserialize from JSON.
  factory SavedStream.fromJson(Map<String, dynamic> json) {
    return SavedStream(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}
