import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/src/rust/frb_generated.dart';

class TestRustApi implements RustLibApi {
  const TestRustApi();

  @override
  String crateApiCommitSourceSetupJson({required String sourceRegistryJson}) {
    return sourceRegistryJson;
  }

  @override
  String crateApiDiagnosticsRuntimeJson() {
    return jsonEncode(<String, dynamic>{
      'title': 'CrispyTivi Diagnostics Runtime',
      'version': '1',
      'validation_summary':
          'Runtime validation and media diagnostics are available for source QA and release support.',
      'ffprobe_available': false,
      'ffmpeg_available': false,
      'reports': <Map<String, dynamic>>[
        <String, dynamic>{
          'source_name': 'Home Fiber IPTV',
          'stream_title': 'Crispy One',
          'category': 'healthy',
          'status_code': 200,
          'response_time_ms': 182,
          'url_hash': 'abc',
          'resume_hash': 'def',
          'resolution_label': '1080p',
          'probe_backend': 'metadata-only',
          'mismatch_warnings': <String>[],
          'detail_lines': <String>['Normalized source validation path'],
        },
      ],
      'notes': <String>[
        'Asset-backed diagnostics snapshot mirrors the retained Rust diagnostics contract.',
      ],
    });
  }

  @override
  String crateApiHydrateRuntimeBundleJson({String? sourceRegistryJson}) {
    return '{}';
  }

  @override
  String crateApiPlaybackRuntimeJson({String? sourceRegistryJson}) {
    return jsonEncode(_samplePlaybackStream());
  }

  @override
  String crateApiPlaybackSessionRuntimeJsonFromStreamJson({
    required String playbackStreamJson,
    int? sourceIndex,
    int? qualityIndex,
    int? audioIndex,
    int? subtitleIndex,
  }) {
    final Map<String, dynamic> stream =
        jsonDecode(playbackStreamJson) as Map<String, dynamic>;
    final List<Map<String, dynamic>> sourceOptions =
        _readOptions(stream, 'source_options');
    final List<Map<String, dynamic>> qualityOptions =
        _readOptions(stream, 'quality_options');
    final List<Map<String, dynamic>> audioOptions =
        _readTrackOptions(stream, 'audio_options');
    final List<Map<String, dynamic>> subtitleOptions =
        _readTrackOptions(stream, 'subtitle_options');

    final int selectedSourceIndex =
        _clampIndex(sourceIndex, sourceOptions.length);
    final int selectedQualityIndex =
        _clampIndex(qualityIndex, qualityOptions.length);
    final int selectedAudioIndex = _clampIndex(audioIndex, audioOptions.length);
    final int selectedSubtitleIndex =
        _clampIndex(subtitleIndex, subtitleOptions.length);

    final Map<String, dynamic>? selectedSource =
        _selectedVariant(sourceOptions, selectedSourceIndex);
    final Map<String, dynamic>? selectedQuality =
        _selectedVariant(qualityOptions, selectedQualityIndex);
    final Map<String, dynamic>? selectedAudio =
        _selectedTrack(audioOptions, selectedAudioIndex);
    final Map<String, dynamic>? selectedSubtitle =
        _selectedTrack(subtitleOptions, selectedSubtitleIndex);

    return jsonEncode(<String, dynamic>{
      'playback_uri':
          _uriOf(selectedQuality) ??
          _uriOf(selectedSource) ??
          (stream['uri'] as String? ?? ''),
      'chooser_groups': <Map<String, dynamic>>[
        _chooserGroupFromVariants(
          kind: 'source',
          title: 'Source',
          options: sourceOptions,
          selectedIndex: selectedSourceIndex,
          fallbackLabel: 'Primary source',
        ),
        _chooserGroupFromVariants(
          kind: 'quality',
          title: 'Quality',
          options: qualityOptions,
          selectedIndex: selectedQualityIndex,
          fallbackLabel: 'Auto',
        ),
        _chooserGroupFromTracks(
          kind: 'audio',
          title: 'Audio',
          options: audioOptions,
          selectedIndex: selectedAudioIndex,
        ),
        _chooserGroupFromTracks(
          kind: 'subtitles',
          title: 'Subtitles',
          options: subtitleOptions,
          selectedIndex: selectedSubtitleIndex,
        ),
      ],
      'selected_source_option': selectedSource,
      'selected_quality_option': selectedQuality,
      'selected_audio_option': selectedAudio,
      'selected_subtitle_option': selectedSubtitle,
    });
  }

  @override
  String crateApiSourceRegistryJson() {
    return _sampleSourceRegistryJson;
  }

  @override
  String crateApiUpdateSourceSetupJson({
    required String sourceRegistryJson,
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  }) {
    final SourceRegistrySnapshot snapshot = SourceRegistrySnapshot.fromJsonString(
      sourceRegistryJson,
    );
    final Map<String, dynamic> json = snapshot.toJson();
    final Map<String, dynamic> onboarding =
        (json['onboarding'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<String> stepOrder =
        ((onboarding['step_order'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);
    final String activeStep =
        onboarding['active_step'] as String? ?? 'Source Type';
    final Map<String, dynamic> fieldValues = <String, dynamic>{
      ...((onboarding['field_values'] as Map<String, dynamic>?) ??
          const <String, dynamic>{}),
    };

    switch (action) {
      case 'seed_demo':
        return _sampleSourceRegistryJson;
      case 'start_add':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'add';
        onboarding['active_step'] = 'Source Type';
        if (selectedProviderType != null) {
          onboarding['selected_provider_type'] = selectedProviderType;
        }
      case 'start_edit':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'edit';
        onboarding['active_step'] = 'Connection';
        if (selectedSourceIndex != null) {
          onboarding['selected_source_index'] = selectedSourceIndex;
        }
      case 'start_reconnect':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'reconnect';
        onboarding['active_step'] = 'Credentials';
        if (selectedSourceIndex != null) {
          onboarding['selected_source_index'] = selectedSourceIndex;
        }
      case 'start_import':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'import';
        onboarding['active_step'] = 'Import';
        if (selectedSourceIndex != null) {
          onboarding['selected_source_index'] = selectedSourceIndex;
        }
      case 'select_provider_type':
        if (selectedProviderType != null) {
          onboarding['selected_provider_type'] = selectedProviderType;
        }
      case 'select_wizard_step':
        if (targetStep != null) {
          onboarding['active_step'] = targetStep;
          onboarding['wizard_active'] = true;
        }
      case 'select_source':
        if (selectedSourceIndex != null) {
          onboarding['selected_source_index'] = selectedSourceIndex;
        }
      case 'update_field':
        if (fieldKey != null) {
          fieldValues[fieldKey] = fieldValue ?? '';
          onboarding['field_values'] = fieldValues;
        }
      case 'advance_wizard':
        if (stepOrder.isNotEmpty) {
          final int currentIndex = stepOrder.indexOf(activeStep);
          if (currentIndex != -1 && currentIndex + 1 < stepOrder.length) {
            onboarding['active_step'] = stepOrder[currentIndex + 1];
          }
        }
        onboarding['wizard_active'] = true;
      case 'retreat_wizard':
        if (stepOrder.isNotEmpty) {
          final int currentIndex = stepOrder.indexOf(activeStep);
          if (currentIndex > 0) {
            onboarding['active_step'] = stepOrder[currentIndex - 1];
            onboarding['wizard_active'] = true;
          } else {
            onboarding['wizard_active'] = false;
          }
        } else {
          onboarding['wizard_active'] = false;
        }
      case 'clear_wizard':
        onboarding['wizard_active'] = false;
        onboarding['wizard_mode'] = 'idle';
    }

    json['onboarding'] = onboarding;
    return jsonEncode(json);
  }

  List<Map<String, dynamic>> _readOptions(
    Map<String, dynamic> stream,
    String key,
  ) {
    final Object? raw = stream[key];
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((Map<Object?, Object?> entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readTrackOptions(
    Map<String, dynamic> stream,
    String key,
  ) {
    return _readOptions(stream, key);
  }

  int _clampIndex(int? index, int length) {
    if (length == 0) {
      return 0;
    }
    final int candidate = (index ?? 0).clamp(0, length - 1);
    return candidate;
  }

  Map<String, dynamic>? _selectedVariant(
    List<Map<String, dynamic>> options,
    int index,
  ) {
    if (options.isEmpty) {
      return null;
    }
    return options[index];
  }

  Map<String, dynamic>? _selectedTrack(
    List<Map<String, dynamic>> options,
    int index,
  ) {
    if (options.isEmpty) {
      return null;
    }
    return options[index];
  }

  String? _uriOf(Map<String, dynamic>? option) {
    final Object? value = option?['uri'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  Map<String, dynamic> _chooserGroupFromVariants({
    required String kind,
    required String title,
    required List<Map<String, dynamic>> options,
    required int selectedIndex,
    required String fallbackLabel,
  }) {
    return <String, dynamic>{
      'kind': kind,
      'title': title,
      'options':
          options.isEmpty
              ? <Map<String, dynamic>>[
                <String, dynamic>{'id': 'default', 'label': fallbackLabel},
              ]
              : options
                  .map(
                    (Map<String, dynamic> option) => <String, dynamic>{
                      'id': option['id'] as String? ?? 'default',
                      'label': option['label'] as String? ?? fallbackLabel,
                    },
                  )
                  .toList(growable: false),
      'selected_index': selectedIndex,
    };
  }

  Map<String, dynamic> _chooserGroupFromTracks({
    required String kind,
    required String title,
    required List<Map<String, dynamic>> options,
    required int selectedIndex,
  }) {
    return <String, dynamic>{
      'kind': kind,
      'title': title,
      'options':
          options.isEmpty
              ? <Map<String, dynamic>>[
                <String, dynamic>{'id': 'off', 'label': 'Off'},
              ]
              : options
                  .map(
                    (Map<String, dynamic> option) => <String, dynamic>{
                      'id': option['id'] as String? ?? 'off',
                      'label': option['label'] as String? ?? 'Off',
                    },
                  )
                  .toList(growable: false),
      'selected_index': selectedIndex,
    };
  }

  Map<String, dynamic> _samplePlaybackStream() {
    return <String, dynamic>{
      'uri': 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
      'transport': 'hls',
      'live': false,
      'seekable': true,
      'resume_position_seconds': 0,
      'source_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'primary',
          'label': 'Primary source',
          'uri': 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
          'transport': 'hls',
          'live': false,
          'seekable': true,
          'resume_position_seconds': 0,
        },
        <String, dynamic>{
          'id': 'mirror',
          'label': 'Mirror source',
          'uri':
              'https://stream.crispy-tivi.test/media/the-last-harbor-mirror.m3u8',
          'transport': 'hls',
          'live': false,
          'seekable': true,
          'resume_position_seconds': 0,
        },
      ],
      'quality_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'auto',
          'label': 'Auto',
          'uri': 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
          'transport': 'hls',
          'live': false,
          'seekable': true,
          'resume_position_seconds': 0,
        },
        <String, dynamic>{
          'id': '1080p',
          'label': '1080p',
          'uri':
              'https://stream.crispy-tivi.test/media/the-last-harbor-1080.m3u8',
          'transport': 'hls',
          'live': false,
          'seekable': true,
          'resume_position_seconds': 0,
        },
      ],
      'audio_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'auto',
          'label': 'Main mix',
          'uri':
              'https://stream.crispy-tivi.test/media/the-last-harbor/audio-main.aac',
          'language': 'en',
        },
        <String, dynamic>{
          'id': 'commentary',
          'label': 'Commentary',
          'uri':
              'https://stream.crispy-tivi.test/media/the-last-harbor/audio-commentary.aac',
          'language': 'en',
        },
      ],
      'subtitle_options': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'off', 'label': 'Off', 'uri': ''},
        <String, dynamic>{
          'id': 'en-cc',
          'label': 'English CC',
          'uri':
              'https://stream.crispy-tivi.test/media/the-last-harbor/subtitles-en.vtt',
          'language': 'en',
        },
      ],
    };
  }
}

const String _sampleSourceRegistryJson = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login with live, VOD, and EPG lanes.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {
        "status": "Healthy",
        "progress": "100%",
        "summary": "Ready",
        "primary_action": "Verify access",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Portal access uses credentials."]
      },
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "configured_providers": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login with live, VOD, and EPG lanes.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {
        "status": "Healthy",
        "progress": "100%",
        "summary": "Ready",
        "primary_action": "Verify access",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Portal access uses credentials."]
      },
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "wizard_active": false,
    "wizard_mode": "idle",
    "selected_source_index": 0,
    "field_values": {},
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {"step": "Source Type", "title": "Choose source type", "summary": "Pick provider family.", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Source type", "Display name"], "helper_lines": ["Ordered wizard."]},
      {"step": "Connection", "title": "Add connection details", "summary": "Connection first.", "primary_action": "Validate connection", "secondary_action": "Back", "field_labels": ["Connection endpoint"], "helper_lines": ["Validate first."]},
      {"step": "Credentials", "title": "Authenticate source", "summary": "Credentials second.", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Username", "Password"], "helper_lines": ["Safe unwind."]},
      {"step": "Import", "title": "Choose import scope", "summary": "Pick lanes.", "primary_action": "Start import", "secondary_action": "Back", "field_labels": ["Import scope", "Validation result"], "helper_lines": ["Explicit import."]},
      {"step": "Finish", "title": "Finish setup", "summary": "Return to sources.", "primary_action": "Return to sources", "secondary_action": "Back", "field_labels": ["Validation result", "Import scope"], "helper_lines": ["Done."]}
    ],
    "provider_copy": [
      {"provider_key": "xtream", "provider_type": "Xtream", "title": "Portal", "summary": "Xtream provider.", "helper_lines": ["Credentials required."]}
    ]
  },
  "registry_notes": []
}
''';
