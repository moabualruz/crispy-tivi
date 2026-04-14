import 'dart:convert';

final class DiagnosticsRuntimeSnapshot {
  const DiagnosticsRuntimeSnapshot({
    required this.title,
    required this.version,
    required this.validationSummary,
    required this.ffprobeAvailable,
    required this.ffmpegAvailable,
    required this.reports,
    required this.notes,
  });

  const DiagnosticsRuntimeSnapshot.empty()
    : title = 'CrispyTivi Diagnostics Runtime',
      version = '0',
      validationSummary = 'Diagnostics unavailable.',
      ffprobeAvailable = false,
      ffmpegAvailable = false,
      reports = const <DiagnosticsReport>[],
      notes = const <String>[];

  factory DiagnosticsRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('diagnostics runtime must be a JSON object');
    }
    return DiagnosticsRuntimeSnapshot.fromJson(decoded);
  }

  factory DiagnosticsRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return DiagnosticsRuntimeSnapshot(
      title: _readString(json, 'title', parent: 'diagnostics_runtime'),
      version: _readString(json, 'version', parent: 'diagnostics_runtime'),
      validationSummary: _readString(
        json,
        'validation_summary',
        parent: 'diagnostics_runtime',
      ),
      ffprobeAvailable: _readBool(
        json,
        'ffprobe_available',
        parent: 'diagnostics_runtime',
      ),
      ffmpegAvailable: _readBool(
        json,
        'ffmpeg_available',
        parent: 'diagnostics_runtime',
      ),
      reports: _readReports(json, 'reports', parent: 'diagnostics_runtime'),
      notes: _readOptionalStringList(json, 'notes'),
    );
  }

  final String title;
  final String version;
  final String validationSummary;
  final bool ffprobeAvailable;
  final bool ffmpegAvailable;
  final List<DiagnosticsReport> reports;
  final List<String> notes;
}

final class DiagnosticsReport {
  const DiagnosticsReport({
    required this.sourceName,
    required this.streamTitle,
    required this.category,
    required this.statusCode,
    required this.responseTimeMs,
    required this.urlHash,
    required this.resumeHash,
    required this.resolutionLabel,
    required this.probeBackend,
    required this.mismatchWarnings,
    required this.detailLines,
  });

  factory DiagnosticsReport.fromJson(
    Map<String, dynamic> json, {
    required String parent,
  }) {
    return DiagnosticsReport(
      sourceName: _readString(json, 'source_name', parent: parent),
      streamTitle: _readString(json, 'stream_title', parent: parent),
      category: _readString(json, 'category', parent: parent),
      statusCode: _readInt(json, 'status_code', parent: parent),
      responseTimeMs: _readInt(json, 'response_time_ms', parent: parent),
      urlHash: _readString(json, 'url_hash', parent: parent),
      resumeHash: _readString(json, 'resume_hash', parent: parent),
      resolutionLabel: _readString(json, 'resolution_label', parent: parent),
      probeBackend: _readString(json, 'probe_backend', parent: parent),
      mismatchWarnings: _readStringList(
        json,
        'mismatch_warnings',
        parent: parent,
      ),
      detailLines: _readStringList(json, 'detail_lines', parent: parent),
    );
  }

  final String sourceName;
  final String streamTitle;
  final String category;
  final int statusCode;
  final int responseTimeMs;
  final String urlHash;
  final String resumeHash;
  final String resolutionLabel;
  final String probeBackend;
  final List<String> mismatchWarnings;
  final List<String> detailLines;
}

List<DiagnosticsReport> _readReports(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<DiagnosticsReport>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('$parent.$key must contain only objects');
      }
      return DiagnosticsReport.fromJson(entry, parent: '$parent.$key');
    }),
  );
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$parent.$key must be a non-empty string');
  }
  return value;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$parent.$key must be a bool');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String key, {required String parent}) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$parent.$key must be an int');
  }
  return value;
}

List<String> _readStringList(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<String>.unmodifiable(
    value.map((Object? item) {
      if (item is! String || item.isEmpty) {
        throw FormatException('$parent.$key must contain only strings');
      }
      return item;
    }),
  );
}

List<String> _readOptionalStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array when present');
  }
  return List<String>.unmodifiable(
    value.map((Object? item) {
      if (item is! String || item.isEmpty) {
        throw FormatException('$key must contain only non-empty strings');
      }
      return item;
    }),
  );
}
