Task statement

Implement full-page fake-scroll/windowing for the heavy catalog surfaces and unify the Movies and Series browsers into one shared render path.

Desired outcome

- Guide entry and EPG-only filtering no longer hang the native Linux app on the real configured source.
- Channel list, Movies, and Series use bounded rendering rather than effectively rendering entire large collections.
- Movies and Series share one browser surface for search/sort/filter/category/render behavior while keeping distinct detail/watch behavior.
- Real-source smoke tests pass on web and native checks show materially improved Guide entry memory behavior.

Known facts and evidence

- The implementation plan is saved at `docs/overhaul/plans/render-windowing-unify-browser-20260409.md`.
- Native Guide entry profiling attributed allocation hot paths primarily to Flutter/Skia render paths in `libflutter_linux_gtk.so`.
- Native Guide hang case reached about `812 MB RSS`, `562 MB RssAnon`, and `250 MB RssFile`.
- `VirtualEpgGrid` still renders the full filtered channel body plus sticky channel column.
- Channel list and channel TV layout still use conventional slivers over the full visible channel set.
- Movies and Series still use separate browser implementations and duplicated category/render paths.
- Horizontal VOD rails are only partially windowed; full-screen Guide/channel/browser surfaces are not.

Constraints

- Preserve real-source behavior with the configured Xtream source.
- Keep different detail/watch widgets and navigation where Movies and Series genuinely differ.
- Prefer deletion and consolidation over adding more parallel browser implementations.
- Verify with the real-source smoke flows and Linux build.

Unknowns and open questions

- Whether Guide windowing alone is sufficient to bring native Guide entry below the problematic peak or whether preview/info subtrees also need deferral.
- How far channel list virtualization needs to go beyond stricter sliver windowing.
- Whether the unified browser should absorb TV and compact variants immediately or land in two phases with a shared core first.

Likely codebase touchpoints

- `app/flutter/lib/features/epg/presentation/widgets/virtual_epg_grid.dart`
- `app/flutter/lib/features/epg/presentation/screens/epg_timeline_screen.dart`
- `app/flutter/lib/features/iptv/presentation/screens/channel_list_screen.dart`
- `app/flutter/lib/features/iptv/presentation/widgets/channel_tv_layout.dart`
- `app/flutter/lib/features/vod/presentation/screens/vod_browser_screen.dart`
- `app/flutter/lib/features/vod/presentation/screens/series_browser_screen.dart`
- `app/flutter/lib/features/vod/presentation/widgets/vod_browser_shell.dart`
- `app/flutter/lib/features/vod/presentation/widgets/vod_movies_tab.dart`
- `app/flutter/lib/features/vod/presentation/widgets/series_tv_layout.dart`
- `app/flutter/lib/features/vod/presentation/widgets/series_movies_grid.dart`
