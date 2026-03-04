import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/vod_item.dart';
import 'cast_scroll_row.dart';
import 'vod_detail_body.dart' show MetaRow;

/// "Details" tab for the series detail screen.
///
/// Shows synopsis, genre, year, rating, and format
/// as labeled key-value rows.
class SeriesDetailsTab extends StatelessWidget {
  const SeriesDetailsTab({super.key, required this.series});

  /// The series whose details are displayed.
  final VodItem series;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.lg,
              vertical: CrispySpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Description --
                if (series.description != null &&
                    series.description!.isNotEmpty) ...[
                  Text(
                    'Synopsis',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.sm),
                  Text(
                    series.description!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.lg),
                ],

                // -- Genre / Category --
                if (series.category != null && series.category!.isNotEmpty) ...[
                  MetaRow(
                    label: 'Genre',
                    value: series.category!,
                    textTheme: tt,
                  ),
                  const SizedBox(height: CrispySpacing.md),
                ],

                // -- Year --
                if (series.year != null) ...[
                  MetaRow(
                    label: 'Year',
                    value: '${series.year}',
                    textTheme: tt,
                  ),
                  const SizedBox(height: CrispySpacing.md),
                ],

                // -- Rating --
                if (series.rating != null && series.rating!.isNotEmpty) ...[
                  MetaRow(
                    label: 'Rating',
                    value: series.rating!,
                    textTheme: tt,
                  ),
                  const SizedBox(height: CrispySpacing.md),
                ],

                // -- Format / Extension --
                if (series.extension != null &&
                    series.extension!.isNotEmpty) ...[
                  MetaRow(
                    label: 'Format',
                    value: series.extension!.toUpperCase(),
                    textTheme: tt,
                  ),
                  const SizedBox(height: CrispySpacing.md),
                ],
              ],
            ),
          ),

          // -- Cast & Crew (FE-SRD-07) --
          CastScrollRow(castNames: series.cast),

          const SizedBox(height: CrispySpacing.xl),
        ],
      ),
    );
  }
}
