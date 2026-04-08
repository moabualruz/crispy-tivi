import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/vod_item.dart';
import 'more_like_this_section.dart';

/// "More Like This" tab for the series detail screen.
///
/// Wraps [MoreLikeThisSection] in a scrollable view
/// with standard vertical padding.
class SeriesMoreLikeThisTab extends StatelessWidget {
  const SeriesMoreLikeThisTab({super.key, required this.currentSeries});

  /// The series to find similar items for.
  final VodItem currentSeries;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: CrispySpacing.sm,
        bottom: CrispySpacing.xl,
      ),
      child: MoreLikeThisSection(currentSeries: currentSeries),
    );
  }
}
