import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/error_boundary.dart';
import '../../../cloud_sync/presentation/widgets/cloud_sync_section.dart';
import '../widgets/about_settings.dart';
// FE-S-05
import '../widgets/accessibility_settings.dart';
import '../widgets/admin_settings.dart';
import '../widgets/profile_settings.dart';
import '../widgets/backup_settings.dart';
import '../widgets/cloud_storage_settings.dart';
import '../widgets/device_settings.dart';
import '../widgets/dvr_settings.dart';
import '../widgets/experimental_settings.dart';
import '../widgets/history_settings.dart';
import '../widgets/bandwidth_settings.dart';
import '../widgets/notification_settings.dart';
import '../widgets/parental_settings.dart';
import '../widgets/live_tv_settings.dart';
import '../widgets/playback_settings.dart';
import '../widgets/screensaver_settings.dart';
import '../widgets/remote_settings.dart';
import '../widgets/appearance_settings.dart';
import '../widgets/language_settings.dart';
import '../widgets/settings_search_delegate.dart';
import '../widgets/sources_settings.dart';
import '../widgets/network_diagnostics_settings.dart';
import '../widgets/network_security_settings.dart';
import '../widgets/quick_access_strip.dart';
import '../widgets/storage_settings.dart';
import '../../../../core/utils/focus_restoration_service.dart';
import '../../../../core/widgets/screen_template.dart';
import '../widgets/settings_tv_layout.dart';
import '../widgets/sync_settings.dart';

/// Tab categories for the settings screen.
enum _SettingsTab { general, sources, playback, dataSync, advanced, about }

/// Settings screen — tabbed layout with 6 category tabs.
///
/// All settings persist via [SettingsNotifier] ->
/// SQLite (Rust backend).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  static const _routePath = 'settings';
  late final TabController _tabController;
  bool _focusRestored = false;

  /// Section keys for scroll-to anchoring.
  ///
  /// Callers can pass `extra: {'section': SettingsSection.playback}`
  /// via GoRouter to deep-link directly into a section.
  final Map<SettingsSection, GlobalKey> _sectionKeys = {
    for (final s in SettingsSection.values) s: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _SettingsTab.values.length,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoOpenDialog();
      _checkScrollToSection();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_focusRestored) {
      _focusRestored = true;
      restoreFocus(ref, _routePath, context);
    }
  }

  @override
  void deactivate() {
    saveFocusKey(ref, _routePath);
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkAutoOpenDialog() {
    final state = GoRouterState.of(context);
    final extra = state.extra as Map<String, dynamic>?;
    if (extra != null && extra['action'] == 'addXtream') {
      showAddXtreamDialogFromScreen(context, ref);
    }
  }

  void _checkScrollToSection() {
    final state = GoRouterState.of(context);
    final extra = state.extra as Map<String, dynamic>?;
    if (extra == null) return;

    final sectionName = extra['section'] as String?;
    if (sectionName == null) return;

    final section = SettingsSection.values.firstWhere(
      (s) => s.name == sectionName,
      orElse: () => SettingsSection.sources,
    );
    scrollToSection(section);
  }

  // FE-S-01: Settings search — opens SettingsSearchDelegate via showSearch().
  /// Opens the settings-internal search overlay.
  ///
  /// Delegates to [SettingsSearchDelegate] which filters all settings
  /// labels. On selection, closes the overlay and scrolls to the
  /// matching section via [scrollToSection].
  void _openSettingsSearch(BuildContext context) {
    showSearch<SettingsSection?>(
      context: context,
      delegate: SettingsSearchDelegate(
        onSectionSelected: (section) {
          // Defer until after the search overlay closes and the
          // settings list is fully visible again.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) scrollToSection(section);
          });
        },
      ),
    );
  }

  /// Returns the tab index for the given [section].
  int _tabForSection(SettingsSection section) {
    switch (section) {
      case SettingsSection.profiles:
      case SettingsSection.appearance:
      case SettingsSection.language:
      case SettingsSection.liveTV:
      case SettingsSection.device:
        return _SettingsTab.general.index;

      case SettingsSection.sources:
      case SettingsSection.epgUrls:
      case SettingsSection.userAgent:
        return _SettingsTab.sources.index;

      case SettingsSection.playback:
      case SettingsSection.bandwidth:
      case SettingsSection.accessibility:
      case SettingsSection.screensaver:
        return _SettingsTab.playback.index;

      case SettingsSection.sync:
      case SettingsSection.cloudSync:
      case SettingsSection.cloudStorage:
      case SettingsSection.backup:
      case SettingsSection.storage:
      case SettingsSection.history:
        return _SettingsTab.dataSync.index;

      case SettingsSection.dvr:
      case SettingsSection.remote:
      case SettingsSection.notifications:
      case SettingsSection.contentFilter:
      case SettingsSection.parental:
      case SettingsSection.admin:
      case SettingsSection.network:
      case SettingsSection.experimental:
        return _SettingsTab.advanced.index;

      case SettingsSection.about:
        return _SettingsTab.about.index;
    }
  }

  /// Scrolls the settings list to the given [section].
  ///
  /// Switches to the correct tab first, then scrolls within it.
  /// Can be called externally (e.g., from the settings panel)
  /// after navigating to this screen.
  void scrollToSection(SettingsSection section) {
    // Switch to the correct tab first.
    final tabIndex = _tabForSection(section);
    _tabController.animateTo(tabIndex);

    // Then scroll to the section after a frame delay so the tab
    // content is rendered and the key context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _sectionKeys[section];
      if (key == null) return;
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: CrispyAnimation.emphasis,
        curve: Curves.easeInOut,
        alignment: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      key: TestKeys.settingsScreen,
      appBar: AppBar(
        title: Text(context.l10n.navSettings),
        actions: [
          // Settings-internal search — filters and scrolls to a section.
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: context.l10n.settingsSearchSettings,
            onPressed: () => _openSettingsSearch(context),
          ),
          const AppBarSearchButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.palette_outlined),
              text: context.l10n.settingsGeneral,
            ),
            Tab(
              icon: const Icon(Icons.playlist_add),
              text: context.l10n.settingsSources,
            ),
            Tab(
              icon: const Icon(Icons.play_circle_outline),
              text: context.l10n.settingsPlayback,
            ),
            Tab(icon: const Icon(Icons.sync), text: context.l10n.settingsData),
            Tab(
              icon: const Icon(Icons.tune),
              text: context.l10n.settingsAdvanced,
            ),
            Tab(
              icon: const Icon(Icons.info_outline),
              text: context.l10n.settingsAbout,
            ),
          ],
        ),
      ),
      body: ScreenTemplate(
        focusRestorationKey: 'settings',
        compactBody: settingsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _SettingsShimmer(),
          error:
              (e, _) => ErrorBoundary(
                error: e,
                onRetry: () => ref.invalidate(settingsNotifierProvider),
              ),
          data: (settings) => _buildBody(context, settings),
        ),
        largeBody: settingsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _SettingsShimmer(),
          error:
              (e, _) => ErrorBoundary(
                error: e,
                onRetry: () => ref.invalidate(settingsNotifierProvider),
              ),
          data:
              (settings) => SettingsTvLayout(
                tabController: _tabController,
                settings: settings,
                sectionKeys: _sectionKeys,
                onScrollToSection: scrollToSection,
              ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SettingsState settings) {
    return FocusTraversalGroup(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(settings),
          _buildSourcesTab(settings),
          _buildPlaybackTab(settings),
          _buildDataSyncTab(settings),
          _buildAdvancedTab(settings),
          _buildAboutTab(settings),
        ],
      ),
    );
  }

  // ── Tab: General ─────────────────────────────────────────────────────────

  Widget _buildGeneralTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // FE-S-12: Quick-Access strip — horizontally scrollable icon chips.
        const QuickAccessStrip(),
        const SizedBox(height: CrispySpacing.lg),

        // ── Profiles ──
        SizedBox(
          key: _sectionKeys[SettingsSection.profiles],
          child: const ProfileSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Appearance ──
        SizedBox(
          key: _sectionKeys[SettingsSection.appearance],
          child: const _AppearanceSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Language ──
        SizedBox(
          key: _sectionKeys[SettingsSection.language],
          child: const LanguageSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Live TV ──
        SizedBox(
          key: _sectionKeys[SettingsSection.liveTV],
          child: LiveTvSettingsSection(settings: settings),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── This Device ──
        SizedBox(
          key: _sectionKeys[SettingsSection.device],
          child: const DeviceSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  // ── Tab: Sources ──────────────────────────────────────────────────────────

  Widget _buildSourcesTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // ── Sources ──
        SizedBox(
          key: _sectionKeys[SettingsSection.sources],
          child: SourcesSettingsSection(settings: settings),
        ),
        // ── EPG URLs ──
        if (settings.sources.isNotEmpty) ...[
          const SizedBox(height: CrispySpacing.lg),
          SizedBox(
            key: _sectionKeys[SettingsSection.epgUrls],
            child: EpgUrlSettingsSection(sources: settings.sources),
          ),
        ],

        // ── User Agent ──
        if (settings.sources.isNotEmpty) ...[
          const SizedBox(height: CrispySpacing.lg),
          SizedBox(
            key: _sectionKeys[SettingsSection.userAgent],
            child: UserAgentSettingsSection(sources: settings.sources),
          ),
        ],

        // ── Per-source TLS ──
        if (settings.sources.isNotEmpty) ...[
          const SizedBox(height: CrispySpacing.lg),
          SourceTlsSettingsSection(sources: settings.sources),
        ],

        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  // ── Tab: Playback ─────────────────────────────────────────────────────────

  Widget _buildPlaybackTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // ── Playback ──
        SizedBox(
          key: _sectionKeys[SettingsSection.playback],
          child: const PlaybackSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // FE-S-04: Data & Bandwidth section — quality cap, cellular limit, data-saving.
        // ── Data & Bandwidth ──
        SizedBox(
          key: _sectionKeys[SettingsSection.bandwidth],
          child: BandwidthSettingsSection(settings: settings),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // FE-S-05: Accessibility settings section.
        // ── Accessibility ──
        SizedBox(
          key: _sectionKeys[SettingsSection.accessibility],
          child: const AccessibilitySettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Screensaver ──
        SizedBox(
          key: _sectionKeys[SettingsSection.screensaver],
          child: ScreensaverSettingsSection(settings: settings),
        ),
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  // ── Tab: Data & Sync ──────────────────────────────────────────────────────

  Widget _buildDataSyncTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // ── Sync (incl. Web Local) ──
        SizedBox(
          key: _sectionKeys[SettingsSection.sync],
          child: SyncSettingsSection(settings: settings),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Cloud Sync ──
        SizedBox(
          key: _sectionKeys[SettingsSection.cloudSync],
          child: const CloudSyncSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Cloud Storage ──
        SizedBox(
          key: _sectionKeys[SettingsSection.cloudStorage],
          child: const CloudStorageSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Backup & Restore ──
        SizedBox(
          key: _sectionKeys[SettingsSection.backup],
          child: const BackupSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // FE-S-02: Settings-specific import/export (preferences only).
        const SettingsImportExportSection(),
        const SizedBox(height: CrispySpacing.lg),

        // FE-S-06: Storage & Cache section — cache sizes, clear per type, clear all.
        // ── Storage & Cache ──
        SizedBox(
          key: _sectionKeys[SettingsSection.storage],
          child: const StorageSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── History ──
        SizedBox(
          key: _sectionKeys[SettingsSection.history],
          child: const HistorySettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  // ── Tab: Advanced ─────────────────────────────────────────────────────────

  Widget _buildAdvancedTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // ── DVR & Recordings ──
        SizedBox(
          key: _sectionKeys[SettingsSection.dvr],
          child: const DvrSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Remote Control ──
        SizedBox(
          key: _sectionKeys[SettingsSection.remote],
          child: RemoteSettingsSection(remoteKeyMap: settings.remoteKeyMap),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Notifications ──
        SizedBox(
          key: _sectionKeys[SettingsSection.notifications],
          child: NotificationSettingsSection(settings: settings),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Content Filter ──
        SizedBox(
          key: _sectionKeys[SettingsSection.contentFilter],
          child: ContentFilterSettingsSection(
            hiddenGroups: settings.hiddenGroups,
          ),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Parental Controls ──
        SizedBox(
          key: _sectionKeys[SettingsSection.parental],
          child: const ParentalSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Admin ──
        SizedBox(
          key: _sectionKeys[SettingsSection.admin],
          child: const AdminSettingsSection(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // FE-S-11: Network Diagnostics — tile opens sheet with connection/DNS/latency checks.
        // ── Network Diagnostics ──
        SizedBox(
          key: _sectionKeys[SettingsSection.network],
          child: const NetworkDiagnosticsTile(),
        ),
        const SizedBox(height: CrispySpacing.lg),

        // ── Network Security (TLS) ──
        const NetworkSecuritySection(),
        const SizedBox(height: CrispySpacing.lg),

        // ── Experimental ──
        SizedBox(
          key: _sectionKeys[SettingsSection.experimental],
          child: ExperimentalSettingsSection(
            upscaleEnabled: settings.config.player.upscaleEnabled,
          ),
        ),
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }

  // ── Tab: About ────────────────────────────────────────────────────────────

  Widget _buildAboutTab(SettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        // ── About ──
        SizedBox(
          key: _sectionKeys[SettingsSection.about],
          child: AboutSettingsSection(appVersion: settings.config.appVersion),
        ),
        const SizedBox(height: CrispySpacing.xl),
      ],
    );
  }
}

/// Enum identifying each navigable section of [SettingsScreen].
///
/// Pass via GoRouter `extra: {'section': SettingsSection.playback.name}`
/// to deep-link into a specific section, or use
/// [_SettingsScreenState.scrollToSection] directly.
enum SettingsSection {
  profiles,
  sources,
  dvr,
  sync,
  appearance,
  playback,
  liveTV,
  remote,
  notifications,
  bandwidth,
  storage,
  network,
  contentFilter,
  history,
  parental,
  // FE-S-05
  accessibility,
  screensaver,
  admin,
  epgUrls,
  userAgent,
  backup,
  device,
  cloudSync,
  language,
  cloudStorage,
  experimental,
  about,
}

/// S-10: Skeleton shimmer shown while settings data loads.
///
/// Renders a stack of fading placeholder tiles that match the rough
/// visual structure of the settings list. Uses a single
/// [AnimationController] to keep memory overhead low.
class _SettingsShimmer extends StatefulWidget {
  const _SettingsShimmer();

  @override
  State<_SettingsShimmer> createState() => _SettingsShimmerState();
}

class _SettingsShimmerState extends State<_SettingsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CrispyAnimation.dramatic)
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final color = Color.lerp(base, highlight, _anim.value)!;
            return ListView.separated(
              padding: const EdgeInsets.all(CrispySpacing.md),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder:
                  (_, _) => const SizedBox(height: CrispySpacing.lg),
              itemBuilder: (_, i) => _ShimmerSection(color: color, index: i),
            );
          },
        ),
      ),
    );
  }
}

/// A single shimmer section placeholder.
class _ShimmerSection extends StatelessWidget {
  const _ShimmerSection({required this.color, required this.index});

  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Vary widths so the placeholder feels organic.
    final titleW = 80.0 + (index % 3) * 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header placeholder.
        Container(
          width: titleW,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(CrispyRadius.xs),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        // Two tile placeholders per section.
        for (var j = 0; j < 2; j++) ...[
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(CrispyRadius.xs),
            ),
          ),
          if (j == 0) const SizedBox(height: CrispySpacing.xs),
        ],
      ],
    );
  }
}

/// S-12: Appearance section shim — delegates to [AppearanceSettingsSection].
///
/// Kept as a private shim so the [SettingsScreen] reference compiles.
/// The implementation lives in `appearance_settings.dart`.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) => const AppearanceSettingsSection();
}
