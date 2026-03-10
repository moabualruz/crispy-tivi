import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/device_form_factor.dart';

/// Wraps [child] with pinch-to-zoom gesture detection that translates the
/// pinch scale into a discrete column-count change.
///
/// Pinching in (scale > 1.3) decreases the column count (bigger cards).
/// Pinching out (scale < 0.7) increases the column count (smaller cards).
/// Column changes are debounced to 300 ms to prevent rapid-fire updates.
///
/// On non-mobile form factors (desktop, TV, web) the gesture layer is
/// omitted and [child] is returned as-is because pinch gestures are not
/// available on those platforms.
///
/// ```dart
/// PinchToZoomGrid(
///   initialColumns: 4,
///   onColumnCountChanged: (cols) => setState(() => _columns = cols),
///   child: GridView.builder(...),
/// )
/// ```
class PinchToZoomGrid extends StatefulWidget {
  /// Creates a [PinchToZoomGrid].
  const PinchToZoomGrid({
    super.key,
    required this.child,
    required this.onColumnCountChanged,
    this.minColumns = 2,
    this.maxColumns = 8,
    this.initialColumns = 4,
  });

  /// The grid widget to wrap. Receives the full available space.
  final Widget child;

  /// Called whenever the pinch gesture crosses a column-count threshold.
  ///
  /// The new column count is clamped to [[minColumns], [maxColumns]].
  final ValueChanged<int> onColumnCountChanged;

  /// Minimum number of columns reachable by pinching in. Defaults to `2`.
  final int minColumns;

  /// Maximum number of columns reachable by pinching out. Defaults to `8`.
  final int maxColumns;

  /// Column count at widget creation time. Defaults to `4`.
  final int initialColumns;

  @override
  State<PinchToZoomGrid> createState() => _PinchToZoomGridState();
}

class _PinchToZoomGridState extends State<PinchToZoomGrid> {
  /// Current column count, mutated on each threshold crossing.
  late int _columns;

  /// Scale captured at the start of the active pinch gesture.
  double _baseScale = 1.0;

  /// Timestamp of the most recent column-count change, used for debouncing.
  DateTime _lastChangeTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Minimum elapsed time between column-count changes.
  static const Duration _debounce = Duration(milliseconds: 300);

  /// Scale threshold above which column count decreases (zoom in).
  static const double _zoomInThreshold = 1.3;

  /// Scale threshold below which column count increases (zoom out).
  static const double _zoomOutThreshold = 0.7;

  @override
  void initState() {
    super.initState();
    _columns = widget.initialColumns;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = details.scale / _baseScale;
    final now = DateTime.now();

    if (now.difference(_lastChangeTime) < _debounce) return;

    if (scale > _zoomInThreshold && _columns > widget.minColumns) {
      setState(() => _columns--);
      _lastChangeTime = now;
      _baseScale = details.scale;
      HapticFeedback.selectionClick();
      widget.onColumnCountChanged(_columns);
    } else if (scale < _zoomOutThreshold && _columns < widget.maxColumns) {
      setState(() => _columns++);
      _lastChangeTime = now;
      _baseScale = details.scale;
      HapticFeedback.selectionClick();
      widget.onColumnCountChanged(_columns);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formFactor = DeviceFormFactorService.current;

    // Pinch gestures are only meaningful on touch-capable mobile devices.
    if (!formFactor.isMobile) {
      return widget.child;
    }

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: widget.child,
    );
  }
}
