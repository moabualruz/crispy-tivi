import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, ServerSocket, Socket, exitCode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, rootBundle;
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_config.dart';
import 'config/settings_notifier.dart';
import 'l10n/app_localizations.dart';
import 'core/data/app_directories.dart';
import 'core/data/app_startup_provider.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/crispy_animation.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/device_form_factor.dart';
import 'core/utils/perf_monitor.dart';
import 'core/utils/input_mode_notifier.dart';
import 'core/data/cache_service.dart';
import 'core/data/event_driven_invalidator.dart';
import 'core/data/ffi_backend.dart';
import 'core/data/ws_backend.dart';
import 'core/utils/timezone_utils.dart';
import 'core/widgets/media_query_scaler.dart';
import 'core/widgets/responsive_layout.dart';
import 'core/widgets/smart_image.dart';
import 'core/widgets/error_boundary.dart';
import 'core/widgets/splash_screen.dart';
import 'core/utils/window_config.dart';
import 'core/widgets/ui_auto_scale.dart';
import 'features/iptv/presentation/providers/playlist_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

/// Port for single-instance detection on desktop.
const int _kSingleInstancePort = 45678;

/// Set to `true` before calling [main] in integration tests
/// to skip the single-instance socket check (port 45678).
bool skipSingleInstanceCheck = false;

/// SharedPreferences keys for window state persistence.
const String _kWinX = 'win_x';
const String _kWinY = 'win_y';
const String _kWinW = 'win_w';
const String _kWinH = 'win_h';
const String _kWinMax = 'win_max';

/// Computes UI auto-scale factor for high-resolution screens.
///
/// Only applies on desktop and Android TV — phones and tablets use
/// native DPI scaling and should never be auto-scaled.
///
/// On **Linux** (both Wayland and X11), Flutter reports
/// `devicePixelRatio = 1.0` unless the user explicitly sets
/// `GDK_SCALE` or compositor fractional scaling. This makes the
/// formula produce wildly incorrect values (e.g. 3.56× on a 3287px
/// display). Auto-scale is therefore **disabled on Linux when
/// DPR ≤ 1.0** — the OS is not requesting HiDPI and the app should
/// not second-guess it. When the user HAS configured fractional
/// scaling (DPR > 1.0), the standard formula applies.
///
/// Below 1440px physical height: 1.0 (no scaling).
/// 1440–2160px: linear interpolation from 1.0 to 2.0.
/// Above 2160px: continues scaling linearly (e.g. 8K will be ~4.75).
double computeUiAutoScale(double logicalHeight, double devicePixelRatio) {
  if (!DeviceFormFactorService.current.supportsAutoScale) return 1.0;

  // Use logicalHeight directly — it is already DPR-normalized
  // (physical pixels / devicePixelRatio), making this formula
  // platform-agnostic with no OS-specific guards.
  //
  // Below 1440 logical: no scaling — the layout fits naturally.
  // At 1440 and above: lock the effective layout to 1440 logical
  // pixels of content. This preserves the same visual density
  // regardless of display resolution or compositor DPR.
  //
  // Examples:
  // - 655 logical (small window)   → 1.0  (no scale)
  // - 1080 logical (4K@DPR=2)     → 1.0  (threshold, no scale)
  // - 1440 logical (1440p@DPR=1)  → 1.33 (locked to 1080 effective)
  // - 1830 logical (ultrawide@2)  → 1.69 (locked to 1080 effective)
  // - 2160 logical (4K@DPR=1)     → 2.0  (locked to 1080 effective)
  if (logicalHeight <= 1080) {
    return 1.0;
  }

  return logicalHeight / 1080;
}

/// Returns true when this is the first app instance on desktop.
///
/// Binds a [ServerSocket] on [_kSingleInstancePort]. If the port
/// is already in use another instance is running: connect to it
/// (triggering its focus handler) then return false so the caller
/// can exit.
Future<bool> _ensureSingleInstance() async {
  if (kIsWeb) return true;
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return true;
  }
  try {
    final server = await ServerSocket.bind('127.0.0.1', _kSingleInstancePort);
    server.listen((socket) async {
      // A second instance connected — bring this window to front.
      await windowManager.show();
      await windowManager.focus();
      socket.destroy();
    });
    return true;
  } on SocketException {
    // Another instance is already running — signal it and exit.
    try {
      final socket = await Socket.connect('127.0.0.1', _kSingleInstancePort);
      await socket.close();
    } catch (_) {}
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceFormFactorService.init();

  final configString = await rootBundle.loadString(
    'assets/config/app_config.json',
  );
  final jsonMap = json.decode(configString) as Map<String, dynamic>;
  final config = AppConfig.fromJson(jsonMap);

  // ── Image cache limits ──────────────────────────────────
  // Cap in-memory decoded-image cache to limit RAM growth.
  // maxImageCacheMb default is 20 MB; maxImageMemCacheObjects caps the count.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = config.cache.maxImageCacheMb * 1024 * 1024
    ..maximumSize = config.cache.maxImageMemCacheObjects;

  // Force landscape on mobile phones (shortestSide < 600dp).
  // Uses PlatformDispatcher pre-runApp — no BuildContext needed.
  // Fallback in MaterialApp.router builder handles rare 0×0 case.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view != null) {
      final logicalSize = view.physicalSize / view.devicePixelRatio;
      if (logicalSize.shortestSide > 0 && logicalSize.shortestSide < 600) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  // Single-instance guard (desktop only).
  if (!skipSingleInstanceCheck && !await _ensureSingleInstance()) {
    // Another instance is already running and has been signalled to focus.
    exitCode = 0;
    return;
  }

  if (!kIsWeb) {
    MediaKit.ensureInitialized();
    await AppDirectories.ensureCreated();
  }

  final backend = kIsWeb ? WsBackend() : FfiBackend();
  if (kIsWeb) {
    // 1. Check dart-define override first
    int port = const int.fromEnvironment('CRISPY_PORT', defaultValue: 0);

    // 2. Fallback to app_config.json
    if (port == 0) {
      port = config.api.backendPort;
    }

    // Use Uri.base.host to allow network access to the web app, fallback to 127.0.0.1
    final String host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
    final String serverBaseUrl = 'http://$host:$port';
    await backend.init(serverBaseUrl);
    // Route web images through the server proxy to bypass browser CORS.
    SmartImage.proxyBaseUrl = serverBaseUrl;
  } else {
    // On native, rust_api initializes with the DB path.
    await backend.init('${AppDirectories.data}/crispy_tivi_v2.sqlite');
  }

  // Wire TimezoneUtils to the backend once at startup so
  // timezone offset lookups are available before the first
  // provider reads (avoids calling setBackend inside a Provider).
  TimezoneUtils.setBackend(backend);

  // Desktop window setup BEFORE runApp so the window is at its
  // final size when Flutter renders the first frame. Without this,
  // starting maximized shows squished UI until a manual resize.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    // Adaptive default: 1080p window for <=1440p screens, 1440p for larger.
    var initialSize = const Size(1920.0, 1080.0);
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    if (displays.isNotEmpty) {
      final screenHeight = displays.first.size.height;
      initialSize =
          screenHeight > 1440 ? const Size(2560, 1440) : const Size(1920, 1080);
    }
    var shouldCenter = true;
    Offset? savedPosition;
    var savedMax = false;

    if (kPersistWindowState) {
      // Restore persisted window state (or fall back to defaults).
      final prefs = await SharedPreferences.getInstance();
      initialSize = Size(
        prefs.getDouble(_kWinW) ?? initialSize.width,
        prefs.getDouble(_kWinH) ?? initialSize.height,
      );
      final savedX = prefs.getDouble(_kWinX);
      final savedY = prefs.getDouble(_kWinY);
      if (savedX != null && savedY != null) {
        savedPosition = Offset(savedX, savedY);
        shouldCenter = false;
      }
      savedMax = prefs.getBool(_kWinMax) ?? false;
    }

    final windowOptions = WindowOptions(
      size: initialSize,
      minimumSize: const Size(800, 480),
      title: 'CrispyTivi',
      center: shouldCenter,
      titleBarStyle:
          kUseCustomTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );

    // Intercept close to clean up backend resources before destroying.
    await windowManager.setPreventClose(true);

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (kPersistWindowState) {
        if (savedPosition != null) {
          await windowManager.setPosition(savedPosition);
        }
        if (savedMax) {
          await windowManager.maximize();
        }
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ── Global error overrides ──────────────────────────────
  // Catch Flutter framework errors (widget build, layout, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };

  // Replace the red error screen with a recoverable ErrorBoundary.
  ErrorWidget.builder =
      (details) => Material(
        child: ErrorBoundary(error: details.exception, onRetry: null),
      );

  // Catch uncaught async errors (unhandled Future rejections, etc.)
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  // runApp in the same zone as ensureInitialized to avoid
  // "Zone mismatch" warning from the Flutter framework.
  runApp(
    ProviderScope(
      overrides: [crispyBackendProvider.overrideWithValue(backend)],
      child: const CrispyTiviApp(),
    ),
  );

  // Start CPU/RAM/frame-timing monitor (debug/profile only).
  PerfMonitor.instance.start();
}

/// Root application widget.
///
/// Watches [settingsNotifierProvider] for reactive config,
/// then builds a [MaterialApp.router] with adaptive theming
/// and [GoRouter]-based navigation.
class CrispyTiviApp extends ConsumerStatefulWidget {
  const CrispyTiviApp({super.key});

  @override
  ConsumerState<CrispyTiviApp> createState() => _CrispyTiviAppState();
}

class _CrispyTiviAppState extends ConsumerState<CrispyTiviApp>
    with WindowListener {
  /// Guards the orientation-lock fallback so it runs at most once.
  bool _orientationLocked = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // Start sync once the startup provider has resolved.
    // No artificial delay — the splash screen already
    // covers the initial frames.
    ref.listenManual(appStartupProvider, (prev, next) {
      if (next.hasValue && mounted) {
        ref.read(playlistSyncServiceProvider).syncAll();
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // ── Window state persistence ──────────────────────────────

  @override
  void onWindowClose() async {
    if (kIsWeb) {
      await windowManager.destroy();
      return;
    }
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      await windowManager.destroy();
      return;
    }
    if (kPersistWindowState) {
      // Save non-maximized bounds before destroying.
      final prefs = await SharedPreferences.getInstance();
      final isMax = await windowManager.isMaximized();
      if (!isMax) {
        final size = await windowManager.getSize();
        final pos = await windowManager.getPosition();
        await prefs.setDouble(_kWinW, size.width);
        await prefs.setDouble(_kWinH, size.height);
        await prefs.setDouble(_kWinX, pos.dx);
        await prefs.setDouble(_kWinY, pos.dy);
      }
      await prefs.setBool(_kWinMax, isMax);
    }
    // Clean up backend resources (WsBackend: socket, timers, streams).
    await ref.read(crispyBackendProvider).dispose();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // Activate event-driven provider invalidation.
    ref.watch(eventDrivenInvalidatorProvider);

    final startupAsync = ref.watch(appStartupProvider);

    return AnimatedSwitcher(
      duration: CrispyAnimation.normal,
      switchInCurve: CrispyAnimation.enterCurve,
      child: startupAsync.when(
        loading: () => const SplashScreen(),
        error:
            (error, stack) => MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: Text('Config error: $error'))),
            ),
        data: (_) => _buildApp(context),
      ),
    );
  }

  Widget _buildApp(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider).requireValue;
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    final appTheme = AppTheme.fromThemeState(themeState);

    // Apply visual density from theme settings.
    final darkThemeData = appTheme.theme.copyWith(
      visualDensity: themeState.density.visualDensity,
    );

    // Light theme — standard M3 light palette using the same seed.
    final lightThemeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: themeState.primaryColor),
      visualDensity: themeState.density.visualDensity,
    );

    return MediaQueryScaler(
      enable: DeviceFormFactorService.current.isTV,
      child: InputModeDetector(
        child: MaterialApp.router(
          title: settings.config.appName,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale != null ? Locale(settings.locale!) : null,
          theme: lightThemeData,
          darkTheme: darkThemeData,
          themeMode: ThemeMode.dark,
          routerConfig: router,
          builder: (context, child) {
            // Fallback orientation lock: if PlatformDispatcher
            // reported 0×0 at startup, lock here on first build.
            if (!_orientationLocked && context.isPhoneFormFactor) {
              _orientationLocked = true;
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            }

            // Compute auto-scale for 1440p+ screens, then apply
            // text scale from theme settings.
            final mq = MediaQuery.of(context);
            final autoScale = computeUiAutoScale(
              mq.size.height,
              mq.devicePixelRatio,
            );
            final scaledSize =
                autoScale > 1.0
                    ? Size(
                      mq.size.width / autoScale,
                      mq.size.height / autoScale,
                    )
                    : mq.size;

            final scaledData = mq.copyWith(
              textScaler: TextScaler.linear(themeState.textScale),
              size: scaledSize,
              devicePixelRatio:
                  autoScale > 1.0 ? mq.devicePixelRatio * autoScale : null,
            );

            Widget result = child ?? const SizedBox.shrink();

            // Scale UI for high-res displays (e.g. 4K at 100% DPI).
            // FittedBox handles painting, layout AND hit-testing
            // correctly — unlike Transform.scale which only paints.
            if (autoScale > 1.0) {
              result = SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: mq.size.width / autoScale,
                    height: mq.size.height / autoScale,
                    child: result,
                  ),
                ),
              );
            }

            return UiAutoScale(
              scale: autoScale,
              child: MediaQuery(data: scaledData, child: result),
            );
          },
        ),
      ),
    );
  }
}
