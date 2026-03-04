/// A time range within a recording where commercial content was detected.
///
/// [startMs] and [endMs] are millisecond offsets from the start of the
/// recording.
class CommercialMarker {
  const CommercialMarker({required this.startMs, required this.endMs});

  /// Start of the commercial break in milliseconds.
  final int startMs;

  /// End of the commercial break in milliseconds.
  final int endMs;

  /// Duration of the commercial break.
  Duration get duration => Duration(milliseconds: endMs - startMs);

  @override
  String toString() => 'CommercialMarker(${startMs}ms - ${endMs}ms)';
}
