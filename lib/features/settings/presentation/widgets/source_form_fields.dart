import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// MAC address validation pattern (case-insensitive hex with colons).
///
/// See [kMacAddressPattern] in `lib/core/constants.dart`.
final kMacAddressRegExp = RegExp(kMacAddressPattern);

/// Form fields for adding an M3U playlist source.
class M3uFormFields extends StatelessWidget {
  const M3uFormFields({
    super.key,
    required this.nameCtrl,
    required this.urlCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'My Playlist',
            prefixIcon: Icon(Icons.label),
          ),
          autofocus: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Playlist URL',
            hintText: 'https://example.com/playlist.m3u',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }
}

/// Form fields for adding an Xtream Codes source.
class XtreamFormFields extends StatelessWidget {
  const XtreamFormFields({
    super.key,
    required this.nameCtrl,
    required this.urlCtrl,
    required this.userCtrl,
    required this.passCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'My IPTV Provider',
            prefixIcon: Icon(Icons.label),
          ),
          autofocus: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'http://provider.com:8080',
            prefixIcon: Icon(Icons.dns),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: userCtrl,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: passCtrl,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
      ],
    );
  }
}

/// Form fields for adding a Stalker Portal source.
class StalkerFormFields extends StatelessWidget {
  const StalkerFormFields({
    super.key,
    required this.nameCtrl,
    required this.urlCtrl,
    required this.macCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController macCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'My Portal',
            prefixIcon: Icon(Icons.label),
          ),
          autofocus: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Portal URL',
            hintText: 'http://portal.example.com',
            prefixIcon: Icon(Icons.dns),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: CrispySpacing.sm),
        TextField(
          controller: macCtrl,
          decoration: const InputDecoration(
            labelText: 'MAC Address',
            hintText: '00:1A:2B:3C:4D:5E',
            prefixIcon: Icon(Icons.router),
            helperText: 'Format: XX:XX:XX:XX:XX:XX',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }
}
