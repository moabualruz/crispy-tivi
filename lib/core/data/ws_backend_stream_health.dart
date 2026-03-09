part of 'ws_backend.dart';

/// Stream health and alternatives WebSocket commands.
mixin _WsStreamHealthMixin on _WsBackendBase {
  // ── Stream Health ──────────────────────────────────

  Future<void> recordStreamStall(String urlHash) async {
    await _send('recordStreamStall', {'urlHash': urlHash});
  }

  Future<void> recordStreamBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) async {
    await _send('recordBufferSample', {
      'urlHash': urlHash,
      'cacheDurationSecs': cacheDurationSecs,
    });
  }

  Future<void> recordStreamTtff(String urlHash, int ttffMs) async {
    await _send('recordTtff', {'urlHash': urlHash, 'ttffMs': ttffMs});
  }

  Future<double> getStreamHealthScore(String urlHash) async {
    final data = await _send('getStreamHealthScore', {'urlHash': urlHash});
    return (data as num).toDouble();
  }

  Future<String> getStreamHealthScores(String urlHashesJson) async {
    final data = await _send('getStreamHealthScores', {
      'urlHashesJson': urlHashesJson,
    });
    return data as String;
  }

  Future<int> pruneStreamHealth(int maxEntries) async {
    final data = await _send('pruneStreamHealth', {'maxEntries': maxEntries});
    return (data as num).toInt();
  }

  Future<String> evaluateFailoverEvent(
    String urlHash,
    String eventType,
    double value,
  ) async {
    final data = await _send('evaluateFailoverEvent', {
      'urlHash': urlHash,
      'eventType': eventType,
      'value': value,
    });
    return data as String;
  }

  Future<void> resetFailoverState(String urlHash) async {
    await _send('resetFailoverState', {'urlHash': urlHash});
  }

  // ── Stream Alternatives ────────────────────────────

  Future<String> rankStreamAlternatives(
    String targetJson,
    String allChannelsJson,
    String healthScoresJson,
  ) async {
    final data = await _send('rankStreamAlternatives', {
      'targetJson': targetJson,
      'allChannelsJson': allChannelsJson,
      'healthScoresJson': healthScoresJson,
    });
    return data as String;
  }

  /// Local Dart fallback — extractCallSign is sync, cannot
  /// use WebSocket. Mirrors Rust regex logic.
  String extractCallSign(String name) {
    // Parenthesized: (WABC), (WCBS)
    final parenMatch = RegExp(r'\(([WKOC][A-Za-z]{2,4})\)').firstMatch(name);
    if (parenMatch != null) return parenMatch.group(1)!.toUpperCase();
    // Standalone: WABC, KCBS
    final upper = name.toUpperCase();
    final standaloneMatch = RegExp(r'\b([WK][A-Z]{2,4})\b').firstMatch(upper);
    if (standaloneMatch != null) return standaloneMatch.group(1)!;
    return '';
  }
}
