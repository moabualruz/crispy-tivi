import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_service.dart';
import 'data_change_event.dart';

/// Typed event stream from the Rust backend.
///
/// Deserializes JSON strings from
/// `CrispyBackend.dataEvents` into [DataChangeEvent]
/// objects. Malformed JSON is logged and skipped (never
/// crashes the stream).
final eventBusProvider = StreamProvider<DataChangeEvent>((ref) {
  final backend = ref.watch(crispyBackendProvider);
  return backend.dataEvents.map((json) {
    try {
      return DataChangeEvent.fromJson(json);
    } catch (e) {
      debugPrint('EventBus: failed to parse event: $e');
      return const BulkDataRefresh();
    }
  });
});
