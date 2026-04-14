import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';

abstract class LiveTvRuntimeRepository {
  const LiveTvRuntimeRepository();

  Future<LiveTvRuntimeSnapshot> load();
}
