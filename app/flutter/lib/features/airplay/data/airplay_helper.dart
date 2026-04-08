// AirPlay helper with platform-conditional implementation.
//
// On iOS/macOS: Uses native AVPlayer + AVRoutePickerView via platform channel.
// On other platforms: Returns stub that reports unsupported.
export 'airplay_helper_stub.dart' if (dart.library.io) 'airplay_helper_io.dart';
