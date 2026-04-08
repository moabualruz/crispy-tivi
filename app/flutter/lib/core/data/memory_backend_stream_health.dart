part of 'memory_backend.dart';

/// Stream health and alternatives in-memory
/// implementation for [MemoryBackend].
mixin _MemoryStreamHealthMixin on _MemoryStorage {
  // ── Stream Health ──────────────────────────────────

  Future<void> recordStreamStall(String urlHash) async {
    final entry = streamHealth[urlHash] ?? _emptyHealth();
    entry['stall_count'] = (entry['stall_count'] as int) + 1;
    entry['last_seen'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    streamHealth[urlHash] = entry;
  }

  Future<void> recordStreamBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) async {
    final entry = streamHealth[urlHash] ?? _emptyHealth();
    entry['buffer_sum'] = (entry['buffer_sum'] as double) + cacheDurationSecs;
    entry['buffer_samples'] = (entry['buffer_samples'] as int) + 1;
    entry['last_seen'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    streamHealth[urlHash] = entry;
  }

  Future<void> recordStreamTtff(String urlHash, int ttffMs) async {
    final entry = streamHealth[urlHash] ?? _emptyHealth();
    entry['ttff_ms'] = ttffMs;
    entry['last_seen'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    streamHealth[urlHash] = entry;
  }

  Future<double> getStreamHealthScore(String urlHash) async {
    final entry = streamHealth[urlHash];
    if (entry == null) return 0.5;
    return _computeHealthScore(entry);
  }

  Future<String> getStreamHealthScores(String urlHashesJson) async {
    final hashes = (jsonDecode(urlHashesJson) as List).cast<String>();
    final scores = <String, double>{};
    for (final h in hashes) {
      final entry = streamHealth[h];
      scores[h] = entry != null ? _computeHealthScore(entry) : 0.5;
    }
    return jsonEncode(scores);
  }

  Future<int> pruneStreamHealth(int maxEntries) async {
    if (streamHealth.length <= maxEntries) return 0;
    final sorted =
        streamHealth.entries.toList()..sort(
          (a, b) => (a.value['last_seen'] as int).compareTo(
            b.value['last_seen'] as int,
          ),
        );
    final excess = streamHealth.length - maxEntries;
    final toRemove = sorted.take(excess).map((e) => e.key).toList();
    for (final key in toRemove) {
      streamHealth.remove(key);
    }
    return toRemove.length;
  }

  Future<String> evaluateFailoverEvent(
    String urlHash,
    String eventType,
    double value,
  ) async {
    final counters = failoverCounters[urlHash] ?? [0, 0];

    if (eventType == 'buffer') {
      if (value < 1.0) {
        counters[0]++;
        if (counters[0] >= 4) {
          failoverCounters[urlHash] = counters;
          return '{"action":"start_warming"}';
        }
      } else if (value > 2.0) {
        counters[0] = 0;
      }
    } else if (eventType == 'stall') {
      counters[1]++;
      if (counters[1] >= 6) {
        failoverCounters[urlHash] = counters;
        return '{"action":"swap_warm"}';
      }
    }

    failoverCounters[urlHash] = counters;
    return '{"action":"none"}';
  }

  Future<void> resetFailoverState(String urlHash) async {
    failoverCounters.remove(urlHash);
  }

  // ── Stream Alternatives ────────────────────────────

  Future<String> rankStreamAlternatives(
    String targetJson,
    String allChannelsJson,
    String healthScoresJson,
  ) async {
    final target = jsonDecode(targetJson) as Map<String, dynamic>;
    final all =
        (jsonDecode(allChannelsJson) as List).cast<Map<String, dynamic>>();
    final targetName = (target['name'] as String?)?.toLowerCase() ?? '';
    final targetUrl = target['stream_url'] as String? ?? '';

    // Simple name-match filter: same name, different URL.
    final matches =
        all
            .where(
              (ch) =>
                  (ch['name'] as String?)?.toLowerCase() == targetName &&
                  ch['stream_url'] != targetUrl,
            )
            .toList();
    return jsonEncode(matches);
  }

  String extractCallSign(String name) {
    final parenMatch = RegExp(r'\(([WKOC][A-Za-z]{2,4})\)').firstMatch(name);
    if (parenMatch != null) return parenMatch.group(1)!.toUpperCase();
    final upper = name.toUpperCase();
    final standaloneMatch = RegExp(r'\b([WK][A-Z]{2,4})\b').firstMatch(upper);
    if (standaloneMatch != null) return standaloneMatch.group(1)!;
    return '';
  }

  // ── Helpers ────────────────────────────────────────

  Map<String, dynamic> _emptyHealth() => {
    'stall_count': 0,
    'buffer_sum': 0.0,
    'buffer_samples': 0,
    'ttff_ms': 0,
    'last_seen': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  };

  double _computeHealthScore(Map<String, dynamic> entry) {
    final stallCount = entry['stall_count'] as int;
    final bufferSum = entry['buffer_sum'] as double;
    final bufferSamples = entry['buffer_samples'] as int;
    final ttffMs = entry['ttff_ms'] as int;
    final lastSeen = entry['last_seen'] as int;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ageHours = (now - lastSeen) / 3600.0;
    final decay = 1.0 / (1.0 + ageHours / (7 * 24));

    final stallScore = 1.0 / (1.0 + stallCount * 0.3);
    final bufferScore =
        bufferSamples > 0
            ? (bufferSum / bufferSamples / 10.0).clamp(0.0, 1.0)
            : 0.5;
    final ttffScore = (1.0 - ttffMs / 10000.0).clamp(0.0, 1.0);

    return decay * (stallScore * 0.5 + bufferScore * 0.3 + ttffScore * 0.2);
  }
}
