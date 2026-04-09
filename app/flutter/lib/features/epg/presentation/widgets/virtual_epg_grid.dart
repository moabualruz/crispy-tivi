import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_colors.dart';
import 'package:flutter/material.dart';
import 'package:crispy_tivi/core/utils/scroll_linker.dart';
import 'package:crispy_tivi/core/widgets/responsive_layout.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/epg/presentation/widgets/epg_date_selector.dart'
    show kEpgDateSelectorHeight;
import 'package:crispy_tivi/features/epg/presentation/widgets/time_header_painter.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';

/// Height of each channel row in the EPG grid (px).
const double kEpgRowHeight = 64.0;

// ── Internal layout constants ────────────────────────────────

/// Width of the "now" time indicator line overlaid on the grid (px).
const double _kNowLineWidth = 2.0;

/// Opacity of the corner-cell border dividers (0–1).
const double _kCornerBorderAlpha = 0.1;

/// Opacity of the row-separator border in the program grid (0–1).
const double _kRowSeparatorAlpha = 0.05;

/// Size of the TV icon rendered in the top-left corner cell (px).
const double _kCornerIconSize = 20.0;

/// Width of the sticky channel column in the EPG grid (px).
///
/// Two breakpoints: compact (< [Breakpoints.expanded]) uses 80 px,
/// expanded (≥ [Breakpoints.expanded]) uses 200 px.
const double kEpgChannelColumnWidthCompact = 80.0;
const double kEpgChannelColumnWidthExpanded = 200.0;

/// A virtualized 2D grid for EPG display.
///
/// Layout:
/// - Sticky Header (Time Scale)
/// - Sticky Left Column (Channels)
/// - Scrollable Body (Programs)
class VirtualEpgGrid extends StatefulWidget {
  final List<Channel> channels;
  final Map<String, List<EpgEntry>> epgEntries;
  final DateTime startDate;
  final DateTime endDate;
  final double pixelsPerMinute;
  final Widget Function(BuildContext context, Channel channel) channelBuilder;
  final Widget Function(
    BuildContext context,
    EpgEntry entry,
    double width,
    double height,
  )
  programBuilder;
  final ScrollController? horizontalScrollController;
  final ScrollController? verticalScrollController;
  final WidgetBuilder? cornerBuilder;

  /// Timezone setting for time header display.
  final String timezone;

  /// View mode (day or week).
  final EpgViewMode viewMode;

  /// Clock function for the "now" line.
  ///
  /// Defaults to [DateTime.now]. Override in tests to
  /// freeze time and produce deterministic goldens.
  final DateTime Function() clock;

  const VirtualEpgGrid({
    super.key,
    required this.channels,
    required this.epgEntries,
    required this.startDate,
    required this.endDate,
    required this.channelBuilder,
    required this.programBuilder,
    this.pixelsPerMinute = 5.0,
    this.horizontalScrollController,
    this.verticalScrollController,
    this.cornerBuilder,
    this.timezone = 'system',
    this.viewMode = EpgViewMode.day,
    this.clock = DateTime.now,
  });

  @override
  State<VirtualEpgGrid> createState() => _VirtualEpgGridState();
}

class _VirtualEpgGridState extends State<VirtualEpgGrid> {
  late ScrollController _headerScroll;
  late ScrollController _bodyHorizontalScroll;
  late ScrollLinker _horizontalLinker;

  late ScrollController _channelsScroll;
  late ScrollController _bodyVerticalScroll;
  late ScrollLinker _verticalLinker;

  /// Height of the sticky time-axis header row (px).
  ///
  /// Mirrors [kEpgDateSelectorHeight] which drives the
  /// `preferredSize` of [EpgAppBar]'s bottom bar — both
  /// must stay in sync so the grid header aligns with the
  /// app-bar selector.
  static const double _headerHeight = kEpgDateSelectorHeight;
  final double _rowHeight = kEpgRowHeight;

  @override
  void initState() {
    super.initState();
    _headerScroll = ScrollController();
    _bodyHorizontalScroll =
        widget.horizontalScrollController ?? ScrollController();
    _horizontalLinker =
        ScrollLinker()
          ..add(_headerScroll)
          ..add(_bodyHorizontalScroll);

    _channelsScroll = ScrollController();
    _bodyVerticalScroll = widget.verticalScrollController ?? ScrollController();
    _verticalLinker =
        ScrollLinker()
          ..add(_channelsScroll)
          ..add(_bodyVerticalScroll);
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _channelsScroll.dispose();
    if (widget.horizontalScrollController == null) {
      _bodyHorizontalScroll.dispose();
    }
    if (widget.verticalScrollController == null) {
      _bodyVerticalScroll.dispose();
    }
    // Linkers just remove listeners now.
    _horizontalLinker.dispose();
    _verticalLinker.dispose();
    super.dispose();
  }

  double get _totalWidth {
    final duration = widget.endDate.difference(widget.startDate);
    return duration.inMinutes * widget.pixelsPerMinute;
  }

  @override
  Widget build(BuildContext context) {
    // Responsive channel column: compact vs expanded breakpoint.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double channelWidth =
        screenWidth >= Breakpoints.expanded
            ? kEpgChannelColumnWidthExpanded
            : kEpgChannelColumnWidthCompact;
    // Total width of the timeline
    final totalWidth = _totalWidth;

    return Stack(
      children: [
        // 3. Body: Program Grid
        Positioned(
          top: _headerHeight,
          left: channelWidth,
          right: 0,
          bottom: 0,
          child: SingleChildScrollView(
            controller: _bodyHorizontalScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _bodyVerticalScroll,
                    itemCount: widget.channels.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, index) {
                      final channel = widget.channels[index];
                      final entries = widget.epgEntries[channel.id] ?? [];
                      return _ProgramRow(
                        entries: entries,
                        startDate: widget.startDate,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        height: _rowHeight,
                        programBuilder: widget.programBuilder,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final now = widget.clock();
                      if (!now.isAfter(widget.startDate) ||
                          !now.isBefore(widget.endDate)) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        left:
                            now.difference(widget.startDate).inMinutes *
                            widget.pixelsPerMinute,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          key: TestKeys.epgNowLine,
                          width: _kNowLineWidth,
                          color: Theme.of(context).crispyColors.epgNowLine,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Left Column: Channels
        Positioned(
          top: _headerHeight,
          left: 0,
          width: channelWidth,
          bottom: 0,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView.builder(
              key: TestKeys.epgChannelList,
              controller: _channelsScroll,
              itemCount: widget.channels.length,
              itemExtent: _rowHeight,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                return SizedBox(
                  height: _rowHeight,
                  width: channelWidth,
                  child: widget.channelBuilder(context, channel),
                );
              },
            ),
          ),
        ),

        // 1. Top Header: Time Timeline
        Positioned(
          top: 0,
          left: channelWidth,
          right: 0,
          height: _headerHeight,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SingleChildScrollView(
              controller: _headerScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                height: _headerHeight,
                child: CustomPaint(
                  painter: TimeHeaderPainter(
                    startDate: widget.startDate,
                    pixelsPerMinute: widget.pixelsPerMinute,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    textStyle: Theme.of(context).textTheme.bodySmall!,
                    timezone: widget.timezone,
                    viewMode: widget.viewMode,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 0. Top-Left Corner (Static)
        Positioned(
          top: 0,
          left: 0,
          width: channelWidth,
          height: _headerHeight,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: _kCornerBorderAlpha),
                ),
                right: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: _kCornerBorderAlpha),
                ),
              ),
            ),
            child:
                widget.cornerBuilder != null
                    ? widget.cornerBuilder!(context)
                    : Icon(
                      Icons.tv,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: _kCornerIconSize,
                    ),
          ),
        ),
      ],
    );
  }
}

class _ProgramRow extends StatelessWidget {
  final List<EpgEntry> entries;
  final DateTime startDate;
  final double pixelsPerMinute;
  final double height;
  final Widget Function(BuildContext, EpgEntry, double, double) programBuilder;

  const _ProgramRow({
    required this.entries,
    required this.startDate,
    required this.pixelsPerMinute,
    required this.height,
    required this.programBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: _kRowSeparatorAlpha),
          ),
        ),
      ),
      child: Stack(
        children:
            entries.map((entry) {
              final rawOffset =
                  entry.startTime.difference(startDate).inMinutes *
                  pixelsPerMinute;
              final startOffset = rawOffset < 0 ? 0.0 : rawOffset;
              final clippedMinutes =
                  rawOffset < 0 ? (rawOffset / pixelsPerMinute).abs() : 0.0;
              final width =
                  (entry.duration.inMinutes - clippedMinutes) * pixelsPerMinute;

              if (width <= 0) return const SizedBox.shrink();

              return Positioned(
                left: startOffset,
                width: width,
                top: 0,
                bottom: 0,
                child: programBuilder(context, entry, width, height),
              );
            }).toList(),
      ),
    );
  }
}

// _TimeHeaderPainter moved to time_header_painter.dart (EPG-T21).
