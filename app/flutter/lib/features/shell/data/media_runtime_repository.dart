import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';

abstract class MediaRuntimeRepository {
  const MediaRuntimeRepository();

  Future<MediaRuntimeSnapshot> load();
}
