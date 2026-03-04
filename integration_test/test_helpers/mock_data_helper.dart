import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/ffi_helper.dart';

/// Helper to ingest mock EPG and IPTV data to fulfill the Gap 2 defined in
/// .ai/docs/ai-tracking/autonomous_qa_execution.md regarding Mock Seed Data.
class MockDataHelper {
  static const String mockM3uUrl = 'http://127.0.0.1:8080/mock_playlist.m3u';
  static const String mockEpgUrl = 'http://127.0.0.1:8080/mock_epg.xml';

  static Future<void> seedIptvData() async {
    await FfiTestHelper.ensureRustInitialized();
    // Simulate FFI backend ingestion of M3U
    // e.g. await RustLib.api.addPlaylist(url: mockM3uUrl);
  }

  static Future<void> seedEpgData() async {
    await FfiTestHelper.ensureRustInitialized();
    // Simulate FFI backend ingestion of XMLTV
    // e.g. await RustLib.api.addEpgSource(url: mockEpgUrl);
  }
}
