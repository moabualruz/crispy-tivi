import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/storage_backend.dart';

/// Dialog for adding or editing a storage backend
/// configuration.
///
/// Shows type-specific form fields based on the
/// selected [StorageType].
class StorageConfigDialog extends StatefulWidget {
  const StorageConfigDialog({super.key, this.backend});

  /// Existing backend to edit; null for new backend.
  final StorageBackend? backend;

  @override
  State<StorageConfigDialog> createState() => _StorageConfigDialogState();
}

class _StorageConfigDialogState extends State<StorageConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late StorageType _type;
  late TextEditingController _nameCtrl;
  late bool _isDefault;

  // Config controllers by key.
  final _configCtrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final b = widget.backend;
    _type = b?.type ?? StorageType.s3;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _isDefault = b?.isDefault ?? false;

    // Pre-populate config fields.
    if (b != null) {
      for (final entry in b.config.entries) {
        _configCtrls[entry.key] = TextEditingController(text: entry.value);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _configCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key) {
    return _configCtrls.putIfAbsent(key, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.backend != null;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Storage Backend' : 'Add Storage Backend'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field.
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g. My NAS',
                  ),
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Name is required'
                              : null,
                ),
                const SizedBox(height: CrispySpacing.md),

                // Type selector (only for new backends).
                if (!isEditing) ...[
                  DropdownButtonFormField<StorageType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items:
                        StorageType.values
                            .where((t) => t != StorageType.local)
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _type = v);
                      }
                    },
                  ),
                  const SizedBox(height: CrispySpacing.md),
                ],

                // Type-specific config fields.
                ..._buildConfigFields(),

                const SizedBox(height: CrispySpacing.sm),

                // Default toggle.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Default upload target'),
                  subtitle: const Text('Auto-upload completed recordings'),
                  value: _isDefault,
                  activeTrackColor: colorScheme.primary,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  List<Widget> _buildConfigFields() {
    switch (_type) {
      case StorageType.s3:
        return _s3Fields();
      case StorageType.webdav:
        return _webdavFields();
      case StorageType.googleDrive:
        return _googleDriveFields();
      case StorageType.ftp:
        return _ftpFields();
      case StorageType.smb:
        return _smbFields();
      case StorageType.local:
        return _localFields();
    }
  }

  List<Widget> _s3Fields() => [
    _field('endpoint', 'Endpoint URL', hint: 'https://s3.amazonaws.com'),
    _field('bucket', 'Bucket Name'),
    _field('region', 'Region', hint: 'us-east-1'),
    _field('accessKey', 'Access Key'),
    _field('secretKey', 'Secret Key', obscure: true),
    _field('pathPrefix', 'Path Prefix', hint: 'recordings'),
  ];

  List<Widget> _webdavFields() => [
    _field('url', 'Server URL', hint: 'https://cloud.example.com/dav'),
    _field('username', 'Username'),
    _field('password', 'Password', obscure: true),
    _field('pathPrefix', 'Path Prefix', hint: 'recordings'),
  ];

  List<Widget> _googleDriveFields() => [
    _field('folderId', 'Folder ID', hint: 'Leave empty to auto-create'),
  ];

  List<Widget> _ftpFields() => [
    _field('host', 'Host'),
    _field('port', 'Port', hint: '22'),
    _field('username', 'Username'),
    _field('password', 'Password', obscure: true),
    _field('pathPrefix', 'Path Prefix', hint: 'recordings'),
  ];

  List<Widget> _smbFields() => [
    _field('host', 'Host / IP Address'),
    _field('share', 'Share Name'),
    _field('username', 'Username'),
    _field('password', 'Password', obscure: true),
    _field('pathPrefix', 'Path Prefix', hint: 'recordings'),
  ];

  List<Widget> _localFields() => [
    _field('path', 'Storage Path', hint: '/path/to/recordings'),
  ];

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CrispySpacing.sm),
      child: TextFormField(
        controller: _ctrl(key),
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final config = <String, String>{};
    for (final entry in _configCtrls.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        config[entry.key] = value;
      }
    }

    final backend = StorageBackend(
      id: widget.backend?.id ?? 'sb_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      type: _type,
      config: config,
      isDefault: _isDefault,
    );

    Navigator.pop(context, backend);
  }
}
