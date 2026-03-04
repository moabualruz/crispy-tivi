/// Stub implementation of WebSyncService for non-web platforms.
/// This ensures the app compiles on Windows/Android even though
/// this feature is Web-only.
class WebSyncService {
  Future<void> pickSyncFolder() async {
    throw UnimplementedError('WebSyncService is only available on Web');
  }

  Future<void> writeToFile(String filename, List<int> bytes) async {
    throw UnimplementedError('WebSyncService is only available on Web');
  }

  Future<List<int>> readFromFile(String filename) async {
    throw UnimplementedError('WebSyncService is only available on Web');
  }
}
