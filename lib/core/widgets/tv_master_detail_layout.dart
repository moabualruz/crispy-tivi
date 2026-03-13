import 'package:flutter/material.dart';

/// A two-panel layout for TV / large screens with a master-detail split.
///
/// By default, the master panel gets 40% of the width (flex=2) and
/// the detail panel gets 60% (flex=3). A [VerticalDivider] separates them.
///
/// ```dart
/// TvMasterDetailLayout(
///   masterPanel: ChannelList(),
///   detailPanel: ChannelDetail(),
/// )
/// ```
class TvMasterDetailLayout extends StatelessWidget {
  /// Creates a TV master-detail layout.
  const TvMasterDetailLayout({
    required this.masterPanel,
    required this.detailPanel,
    this.masterFlex = 2,
    this.detailFlex = 3,
    super.key,
  });

  /// The left/master panel widget.
  final Widget masterPanel;

  /// The right/detail panel widget.
  final Widget detailPanel;

  /// Flex factor for the master panel. Default: 2 (40%).
  final int masterFlex;

  /// Flex factor for the detail panel. Default: 3 (60%).
  final int detailFlex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: masterFlex, child: masterPanel),
        const VerticalDivider(width: 1),
        Expanded(flex: detailFlex, child: detailPanel),
      ],
    );
  }
}
