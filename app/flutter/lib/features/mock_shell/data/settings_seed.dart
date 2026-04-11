import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

const List<SettingsItem> generalSettings = <SettingsItem>[
  SettingsItem(
    title: 'Startup target',
    summary: 'Choose the first screen after launch.',
    value: 'Home',
  ),
  SettingsItem(
    title: 'Recommendations',
    summary: 'Show history-based rails on Home.',
    value: 'On',
  ),
];

const List<SettingsItem> playbackSettings = <SettingsItem>[
  SettingsItem(
    title: 'Quick play confirmation',
    summary: 'Require explicit play confirmation for channel tune.',
    value: 'On',
  ),
  SettingsItem(
    title: 'Preferred quality',
    summary: 'Default target for supported movie streams.',
    value: 'Auto',
  ),
];

const List<SettingsItem> appearanceSettings = <SettingsItem>[
  SettingsItem(
    title: 'Focus intensity',
    summary: 'Boost focus glow for brighter rooms.',
    value: 'Balanced',
  ),
  SettingsItem(
    title: 'Clock display',
    summary: 'Show current time in the top shell area.',
    value: 'On',
  ),
];

const List<SettingsItem> systemSettings = <SettingsItem>[
  SettingsItem(
    title: 'Storage',
    summary: 'Inspect cache and offline data.',
    value: '4.2 GB',
  ),
  SettingsItem(
    title: 'About',
    summary: 'Version, diagnostics, and environment.',
    value: 'v0.1.0-alpha',
  ),
];

const List<SourceHealthItem> sourceHealthItems = <SourceHealthItem>[
  SourceHealthItem(
    name: 'Home Fiber IPTV',
    status: 'Healthy',
    summary: 'Live, guide, and catch-up verified 2 min ago.',
  ),
  SourceHealthItem(
    name: 'Weekend Cinema',
    status: 'Degraded',
    summary: 'Guide present, posters delayed.',
  ),
  SourceHealthItem(
    name: 'Travel Archive',
    status: 'Needs auth',
    summary: 'Reconnect credentials to resume sync.',
  ),
];
