import 'package:crispy_tivi/core/theme/theme.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/presentation/shell_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class CrispyTiviApp extends StatefulWidget {
  const CrispyTiviApp({this.initialContract, this.initialContent, super.key});

  final ShellContractSupport? initialContract;
  final ShellContentSnapshot? initialContent;

  @override
  State<CrispyTiviApp> createState() => _CrispyTiviAppState();
}

class _CrispyTiviAppState extends State<CrispyTiviApp> {
  static const AssetShellBootstrapRepository _bootstrapRepository =
      AssetShellBootstrapRepository();

  late final Future<ShellBootstrap> _bootstrapFuture =
      _createBootstrapFuture();

  Future<ShellBootstrap> _createBootstrapFuture() {
    final ShellContractSupport? injectedContract = widget.initialContract;
    final ShellContentSnapshot? injectedContent = widget.initialContent;
    if (injectedContract != null && injectedContent != null) {
      return SynchronousFuture<ShellBootstrap>(
        ShellBootstrap(
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
      home: FutureBuilder<ShellBootstrap>(
        future: _bootstrapFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<ShellBootstrap> snapshot,
        ) {
          if (snapshot.hasError) {
            return _ContractFailure(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const _ContractLoading();
          }
          return ShellPage(
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
