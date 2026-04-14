import 'package:crispy_tivi/app/app_runtime_mode.dart';
import 'package:crispy_tivi/core/theme/theme.dart';
import 'package:crispy_tivi/features/shell/data/live_tv_runtime_fallback.dart';
import 'package:crispy_tivi/features/shell/data/media_runtime_fallback.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/search_runtime_fallback.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/presentation/shell_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class CrispyTiviApp extends StatefulWidget {
  CrispyTiviApp({
    AppRuntimeProfile? runtimeProfile,
    ShellBootstrapRepository? bootstrapRepository,
    SourceRegistryRepository? sourceRegistryRepository,
    PersonalizationRuntimeRepository? personalizationRepository,
    this.initialContract,
    this.initialContent,
    this.initialSourceRegistry,
    this.initialLiveTvRuntime,
    this.initialMediaRuntime,
    this.initialSearchRuntime,
    this.initialPersonalizationRuntime,
    super.key,
  }) : runtimeProfile = runtimeProfile ?? AppRuntimeConfig.profile,
       bootstrapRepository =
           bootstrapRepository ??
           (runtimeProfile ?? AppRuntimeConfig.profile)
               .createBootstrapRepository(),
       sourceRegistryRepository =
           sourceRegistryRepository ??
           (runtimeProfile ?? AppRuntimeConfig.profile)
               .createSourceRegistryRepository(),
       personalizationRepository =
           personalizationRepository ??
           (runtimeProfile ?? AppRuntimeConfig.profile)
               .createPersonalizationRepository();

  final AppRuntimeProfile runtimeProfile;
  final ShellBootstrapRepository bootstrapRepository;
  final SourceRegistryRepository sourceRegistryRepository;
  final PersonalizationRuntimeRepository personalizationRepository;
  final ShellContractSupport? initialContract;
  final ShellContentSnapshot? initialContent;
  final SourceRegistrySnapshot? initialSourceRegistry;
  final LiveTvRuntimeSnapshot? initialLiveTvRuntime;
  final MediaRuntimeSnapshot? initialMediaRuntime;
  final SearchRuntimeSnapshot? initialSearchRuntime;
  final PersonalizationRuntimeSnapshot? initialPersonalizationRuntime;

  @override
  State<CrispyTiviApp> createState() => _CrispyTiviAppState();
}

class _CrispyTiviAppState extends State<CrispyTiviApp> {
  late final Future<ShellBootstrap> _bootstrapFuture = _createBootstrapFuture();

  Future<ShellBootstrap> _createBootstrapFuture() {
    final ShellContractSupport? injectedContract = widget.initialContract;
    final ShellContentSnapshot? injectedContent = widget.initialContent;
    final SourceRegistrySnapshot injectedSourceRegistry =
        widget.initialSourceRegistry ?? const SourceRegistrySnapshot.empty();
    if (injectedContract != null && injectedContent != null) {
      return SynchronousFuture<ShellBootstrap>(
        ShellBootstrap(
          contract: injectedContract,
          content: injectedContent,
          sourceRegistry: injectedSourceRegistry,
          liveTvRuntime: resolveLiveTvRuntime(
            runtime: widget.initialLiveTvRuntime,
            fallbackContent: injectedContent,
          ),
          mediaRuntime: resolveMediaRuntime(
            runtime: widget.initialMediaRuntime,
            fallbackContent: injectedContent,
          ),
          searchRuntime: resolveSearchRuntime(
            runtime: widget.initialSearchRuntime,
            fallbackContent: injectedContent,
          ),
          personalizationRuntime:
              widget.initialPersonalizationRuntime ??
              const PersonalizationRuntimeSnapshot.empty(),
        ),
      );
    }
    return widget.bootstrapRepository.load();
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
            sourceRegistry: snapshot.data!.sourceRegistry,
            liveTvRuntime: snapshot.data!.liveTvRuntime,
            mediaRuntime: snapshot.data!.mediaRuntime,
            searchRuntime: snapshot.data!.searchRuntime,
            personalizationRuntime: snapshot.data!.personalizationRuntime,
            diagnosticsRuntime: snapshot.data!.diagnosticsRuntime,
            sourceRegistryRepository: widget.sourceRegistryRepository,
            personalizationRepository: widget.personalizationRepository,
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
