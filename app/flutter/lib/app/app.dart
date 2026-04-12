import 'package:crispy_tivi/core/theme/theme.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/mock_shell_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class CrispyTiviApp extends StatefulWidget {
  const CrispyTiviApp({this.initialContract, this.initialContent, super.key});

  final MockShellContractSupport? initialContract;
  final MockShellContentSnapshot? initialContent;

  @override
  State<CrispyTiviApp> createState() => _CrispyTiviAppState();
}

class _CrispyTiviAppState extends State<CrispyTiviApp> {
  static const MockShellBootstrapRepository _bootstrapRepository =
      MockShellBootstrapRepository();

  late final Future<MockShellBootstrap> _bootstrapFuture =
      _createBootstrapFuture();

  Future<MockShellBootstrap> _createBootstrapFuture() {
    final MockShellContractSupport? injectedContract = widget.initialContract;
    final MockShellContentSnapshot? injectedContent = widget.initialContent;
    if (injectedContract != null && injectedContent != null) {
      return SynchronousFuture<MockShellBootstrap>(
        MockShellBootstrap(
          contract: injectedContract,
          content: injectedContent,
        ),
      );
    }
    return _bootstrapRepository.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrispyTivi',
      debugShowCheckedModeBanner: false,
      theme: buildCrispyTheme(),
      supportedLocales: const <Locale>[Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: FutureBuilder<MockShellBootstrap>(
        future: _bootstrapFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<MockShellBootstrap> snapshot,
        ) {
          if (snapshot.hasError) {
            return _ContractFailure(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const _ContractLoading();
          }
          return MockShellPage(
            contract: snapshot.data!.contract,
            content: snapshot.data!.content,
          );
        },
      ),
    );
  }
}

class _ContractLoading extends StatelessWidget {
  const _ContractLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ContractFailure extends StatelessWidget {
  const _ContractFailure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Shell contract failed to load.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
