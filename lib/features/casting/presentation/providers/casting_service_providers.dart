/// Re-exports for casting presentation layer.
///
/// Widgets in [casting/presentation/widgets/] must import from this file
/// instead of reaching directly into data/ layers (DIP / ISP compliance).
export '../../data/cast_service.dart'
    show CastService, CastState, CastDevice, CastMedia, castServiceProvider;
