import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

import '../../../domain/crispy_player.dart';

/// Dialog listing available audio output devices.
///
/// Uses [SimpleDialog] with [ListTile]s for each device from
/// [CrispyPlayer.audioDevices]. Desktop only.
class AudioDevicePickerDialog extends StatelessWidget {
  const AudioDevicePickerDialog({
    required this.devices,
    required this.currentDeviceName,
    required this.onSelect,
    super.key,
  });

  final List<CrispyAudioDevice> devices;
  final String? currentDeviceName;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(context.l10n.playerAudioOutputDevice),
      children: [
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.playerNoAudioDevices),
          )
        else
          ...devices.map(
            (device) => SimpleDialogOption(
              onPressed: () {
                onSelect(device.name);
                Navigator.of(context).pop();
              },
              child: Row(
                children: [
                  Icon(
                    device.name == currentDeviceName
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color:
                        device.name == currentDeviceName
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.description.isNotEmpty
                              ? device.description
                              : device.name,
                        ),
                        if (device.description.isNotEmpty)
                          Text(
                            device.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
