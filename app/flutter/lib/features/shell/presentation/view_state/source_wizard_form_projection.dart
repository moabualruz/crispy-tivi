import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

import 'source_provider_registry.dart';
import 'source_wizard_form.dart';

List<SourceWizardFieldSpec> buildSourceWizardFieldSpecs({
  required List<SourceProviderEntry> providerTypes,
  required SourceProviderKind selectedProviderKind,
  required SourceWizardStep step,
  required Map<String, String> values,
}) {
  final SourceProviderEntry provider = providerTypes.firstWhere(
    (SourceProviderEntry item) => item.providerKind == selectedProviderKind,
    orElse: () => providerTypes.first,
  );

  switch (step) {
    case SourceWizardStep.sourceType:
      final Map<SourceProviderKind, SourceProviderEntry> uniqueKinds =
          <SourceProviderKind, SourceProviderEntry>{
            for (final SourceProviderEntry item in providerTypes)
              item.providerKind: item,
          };
      return <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'source_type',
          label: 'Source type',
          kind: SourceWizardFieldKind.choice,
          options: uniqueKinds.values
              .map(
                (SourceProviderEntry item) => SourceWizardFieldOption(
                  value: item.providerKind.name,
                  label: item.name,
                ),
              )
              .toList(growable: false),
        ),
        const SourceWizardFieldSpec(
          key: 'display_name',
          label: 'Display name',
          kind: SourceWizardFieldKind.text,
          placeholder: 'Provider name in your library',
        ),
      ];
    case SourceWizardStep.connection:
      return _connectionFieldsFor(provider);
    case SourceWizardStep.credentials:
      return _credentialsFieldsFor(provider);
    case SourceWizardStep.importContent:
      return <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'import_scope',
          label: 'Import scope',
          kind: SourceWizardFieldKind.choice,
          options: _importScopeOptions(provider),
        ),
        SourceWizardFieldSpec(
          key: 'validation_result',
          label: 'Validation result',
          kind: SourceWizardFieldKind.readonly,
          readOnlyValue: values['validation_result'] ?? 'Not validated yet',
          required: false,
        ),
      ];
    case SourceWizardStep.finish:
      return <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'validation_result',
          label: 'Validation result',
          kind: SourceWizardFieldKind.readonly,
          readOnlyValue: values['validation_result'] ?? 'Pending',
          required: false,
        ),
        SourceWizardFieldSpec(
          key: 'import_scope',
          label: 'Import scope',
          kind: SourceWizardFieldKind.readonly,
          readOnlyValue: values['import_scope'] ?? 'Default catalog lanes',
          required: false,
        ),
      ];
  }
}

List<SourceWizardFieldSpec> _connectionFieldsFor(SourceProviderEntry provider) {
  switch (provider.providerKind) {
    case SourceProviderKind.m3uUrl:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'playlist_url',
          label: 'Playlist URL',
          kind: SourceWizardFieldKind.url,
          placeholder: 'https://provider.example.com/playlist.m3u',
        ),
        SourceWizardFieldSpec(
          key: 'xmltv_url',
          label: 'XMLTV URL',
          kind: SourceWizardFieldKind.url,
          placeholder: 'https://provider.example.com/guide.xml',
          required: false,
        ),
      ];
    case SourceProviderKind.localM3u:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'playlist_file',
          label: 'Playlist file',
          kind: SourceWizardFieldKind.text,
          placeholder: '/media/iptv/playlist.m3u',
        ),
        SourceWizardFieldSpec(
          key: 'xmltv_file',
          label: 'XMLTV file',
          kind: SourceWizardFieldKind.text,
          placeholder: '/media/iptv/guide.xml',
          required: false,
        ),
      ];
    case SourceProviderKind.xtream:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'server_url',
          label: 'Server URL',
          kind: SourceWizardFieldKind.url,
          placeholder: 'http://provider.example.com:8080',
        ),
      ];
    case SourceProviderKind.stalker:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'portal_url',
          label: 'Portal URL',
          kind: SourceWizardFieldKind.url,
          placeholder: 'http://portal.example.com',
        ),
      ];
  }
}

List<SourceWizardFieldSpec> _credentialsFieldsFor(
  SourceProviderEntry provider,
) {
  switch (provider.providerKind) {
    case SourceProviderKind.m3uUrl:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'headers',
          label: 'Headers',
          kind: SourceWizardFieldKind.multiline,
          placeholder: 'Optional request headers, one per line',
          required: false,
        ),
      ];
    case SourceProviderKind.localM3u:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'headers',
          label: 'Headers',
          kind: SourceWizardFieldKind.multiline,
          placeholder: 'Optional import notes or parsing hints',
          required: false,
        ),
      ];
    case SourceProviderKind.xtream:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'username',
          label: 'Username',
          kind: SourceWizardFieldKind.text,
        ),
        SourceWizardFieldSpec(
          key: 'password',
          label: 'Password',
          kind: SourceWizardFieldKind.password,
        ),
      ];
    case SourceProviderKind.stalker:
      return const <SourceWizardFieldSpec>[
        SourceWizardFieldSpec(
          key: 'mac_address',
          label: 'MAC address',
          kind: SourceWizardFieldKind.text,
          placeholder: '00:1A:79:AB:CD:EF',
        ),
        SourceWizardFieldSpec(
          key: 'device_id',
          label: 'Device ID',
          kind: SourceWizardFieldKind.text,
          placeholder: 'Optional device identifier',
          required: false,
        ),
      ];
  }
}

List<SourceWizardFieldOption> _importScopeOptions(
  SourceProviderEntry provider,
) {
  final List<SourceWizardFieldOption> options = <SourceWizardFieldOption>[
    const SourceWizardFieldOption(value: 'live_tv', label: 'Live TV'),
  ];
  final Set<SourceCapabilityKind> kinds =
      provider.capabilities
          .map((SourceCapabilityDescriptor item) => item.kind)
          .toSet();
  if (kinds.contains(SourceCapabilityKind.guide)) {
    options.add(const SourceWizardFieldOption(value: 'guide', label: 'Guide'));
  }
  if (kinds.contains(SourceCapabilityKind.movies)) {
    options.add(
      const SourceWizardFieldOption(value: 'movies', label: 'Movies'),
    );
  }
  if (kinds.contains(SourceCapabilityKind.series)) {
    options.add(
      const SourceWizardFieldOption(value: 'series', label: 'Series'),
    );
  }
  return List<SourceWizardFieldOption>.unmodifiable(options);
}
