import 'package:flutter/material.dart';

import '../../../data/shader_service.dart';
import 'osd_shared.dart';

/// Shows a shader preset picker dialog over the OSD.
///
/// Returns the selected [ShaderPreset], or `null` if dismissed.
Future<ShaderPreset?> showShaderPresetPicker(
  BuildContext context, {
  required ShaderPreset currentPreset,
}) async {
  return showDialog<ShaderPreset>(
    context: context,
    builder: (ctx) {
      return SimpleDialog(
        title: const Text(
          'Shader Preset',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: osdPanelColor,
        children:
            ShaderPreset.allPresets.map((preset) {
              final isSelected = preset.id == currentPreset.id;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, preset),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.amber : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      );
    },
  );
}
