import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/device_service.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Device settings section for cross-device
/// continuity.
class DeviceSettingsSection extends ConsumerWidget {
  const DeviceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceService = ref.watch(deviceServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'This Device',
          icon: Icons.devices,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        FutureBuilder<DeviceInfo>(
          future: deviceService.getDeviceInfo(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final colorScheme = Theme.of(context).colorScheme;

            return SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Device Name'),
                  subtitle: Text(
                    info?.name ?? 'Loading...',
                    style: TextStyle(
                      color:
                          info?.isCustomName == true
                              ? colorScheme.primary
                              : null,
                    ),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showDeviceNameDialog(context, ref, info?.name),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Device ID'),
                  subtitle: Text(
                    info?.id.substring(0, 8) ?? '...',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colorScheme.outline,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      if (info?.id != null) {
                        Clipboard.setData(ClipboardData(text: info!.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device ID copied')),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showDeviceNameDialog(
    BuildContext context,
    WidgetRef ref,
    String? currentName,
  ) {
    final controller = TextEditingController(text: currentName ?? '');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Device Name'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a custom name for this device '
                  'to identify it when syncing across '
                  'devices.',
                ),
                const SizedBox(height: CrispySpacing.md),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    hintText: 'Living Room TV',
                    prefixIcon: Icon(Icons.devices),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await ref.read(deviceServiceProvider).clearDeviceName();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device name reset')),
                    );
                  }
                },
                child: const Text('Reset to Default'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    await ref.read(deviceServiceProvider).setDeviceName(name);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device name saved')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
