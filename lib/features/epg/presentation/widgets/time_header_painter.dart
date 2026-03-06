import 'package:flutter/material.dart';

import 'package:crispy_tivi/core/theme/crispy_typography.dart';
import 'package:crispy_tivi/core/utils/timezone_utils.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';

/// [CustomPainter] that draws the time-scale header row in the EPG grid.
///
/// Supports two view modes:
/// - [EpgViewMode.day]: draws 30-minute tick marks with HH:MM labels.
/// - [EpgViewMode.week]: draws day dividers and 6-hour sub-ticks.
///
/// Extracted from [VirtualEpgGrid] (EPG-T21).
class TimeHeaderPainter extends CustomPainter {
  const TimeHeaderPainter({
    required this.startDate,
    required this.pixelsPerMinute,
    required this.textColor,
    required this.textStyle,
    this.timezone = 'system',
    this.viewMode = EpgViewMode.day,
  });

  final DateTime startDate;
  final double pixelsPerMinute;
  final Color textColor;
  final TextStyle textStyle;
  final String timezone;
  final EpgViewMode viewMode;

  /// Day names for week-view headers.
  static const _kDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = textColor.withValues(alpha: 0.2)
          ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (viewMode == EpgViewMode.week) {
      _paintWeekView(canvas, size, paint, textPainter);
    } else {
      _paintDayView(canvas, size, paint, textPainter);
    }
  }

  void _paintDayView(
    Canvas canvas,
    Size size,
    Paint paint,
    TextPainter textPainter,
  ) {
    const intervalMinutes = 30;
    final totalMinutes = size.width / pixelsPerMinute;

    for (var i = 0; i < totalMinutes; i += intervalMinutes) {
      final x = i * pixelsPerMinute;
      if (x > size.width) break;

      canvas.drawLine(Offset(x, 25), Offset(x, size.height), paint);

      final time = startDate.add(Duration(minutes: i.toInt()));
      final timeStr = TimezoneUtils.formatTime(time, timezone);

      textPainter.text = TextSpan(
        text: timeStr,
        style: textStyle.copyWith(
          color: textColor,
          fontSize: CrispyTypography.micro,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 5, 10));
    }
  }

  void _paintWeekView(
    Canvas canvas,
    Size size,
    Paint paint,
    TextPainter textPainter,
  ) {
    final dayWidthMinutes = 24 * 60;
    final dayWidthPixels = dayWidthMinutes * pixelsPerMinute;

    for (var day = 0; day < 7; day++) {
      final x = day * dayWidthPixels;
      if (x > size.width) break;

      // Day divider line.
      final dividerPaint =
          Paint()
            ..color = textColor.withValues(alpha: 0.3)
            ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);

      // Day header text (e.g., "Mon 17").
      final dayDate = startDate.add(Duration(days: day));
      final dayName = _kDayNames[dayDate.weekday - 1];
      final dayLabel = '$dayName ${dayDate.day}';

      textPainter.text = TextSpan(
        text: dayLabel,
        style: textStyle.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 8, 8));

      // 6-hour sub-ticks within the day.
      for (var hour = 6; hour < 24; hour += 6) {
        final hourX = x + (hour * 60 * pixelsPerMinute);
        if (hourX > size.width) break;

        canvas.drawLine(Offset(hourX, 30), Offset(hourX, size.height), paint);

        final hourStr = '${hour.toString().padLeft(2, '0')}:00';
        textPainter.text = TextSpan(
          text: hourStr,
          style: textStyle.copyWith(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(hourX + 3, 32));
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimeHeaderPainter oldDelegate) {
    return oldDelegate.startDate != startDate ||
        oldDelegate.pixelsPerMinute != pixelsPerMinute ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.timezone != timezone ||
        oldDelegate.viewMode != viewMode;
  }
}
