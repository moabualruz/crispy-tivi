import 'package:crispy_tivi/core/theme/theme.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/mock_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class CrispyTiviApp extends StatelessWidget {
  const CrispyTiviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrispyTivi',
      debugShowCheckedModeBanner: false,
      theme: buildCrispyTheme(),
      supportedLocales: const <Locale>[Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const MockShellPage(),
    );
  }
}
