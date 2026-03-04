import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ── Minimal File System Access API Interop ───────────────────

extension type FileSystemHandle(JSObject _) implements JSObject {
  external String get name;
  external String get kind;
}

extension type FileSystemDirectoryHandle(JSObject _)
    implements FileSystemHandle {
  external JSPromise<FileSystemFileHandle> getFileHandle(
    String name, [
    FileSystemGetFileOptions options,
  ]);
}

extension type FileSystemFileHandle(JSObject _) implements FileSystemHandle {
  external JSPromise<FileSystemWritableFileStream> createWritable();
  external JSPromise<web.File> getFile();
}

extension type FileSystemWritableFileStream(JSObject _) implements JSObject {
  external JSPromise write(JSAny data);
  external JSPromise close();
}

extension type FileSystemGetFileOptions._(JSObject _) implements JSObject {
  factory FileSystemGetFileOptions({bool create = false}) {
    final obj = JSObject();
    obj['create'] = create.toJS;
    return FileSystemGetFileOptions._(obj);
  }
}

extension WindowFS on web.Window {
  external JSPromise<FileSystemDirectoryHandle> showDirectoryPicker();
}

// ─────────────────────────────────────────────────────────────

/// Service to handle "WASM-style" local file sync on Web
/// using the File System Access API.
class WebSyncService {
  /// The handle to the user-selected local directory.
  FileSystemDirectoryHandle? _dirHandle;

  bool get isSupported => kIsWeb;

  /// Request access to a local folder.
  Future<void> pickSyncFolder() async {
    if (!kIsWeb) return;
    try {
      // Use the extension method defined above
      final promise = web.window.showDirectoryPicker();
      _dirHandle = await promise.toDart;
      debugPrint('WebSync: Picked folder "${_dirHandle?.name}"');
    } catch (e) {
      debugPrint('WebSync: Failed to pick folder: $e');
      rethrow;
    }
  }

  /// Writes a blob (e.g. database export) to the synced folder.
  Future<void> writeToFile(String filename, List<int> bytes) async {
    if (_dirHandle == null) throw Exception('No folder selected');

    try {
      final options = FileSystemGetFileOptions(create: true);
      final handlePromise = _dirHandle!.getFileHandle(filename, options);
      final handle = await handlePromise.toDart;

      final writablePromise = handle.createWritable();
      final writable = await writablePromise.toDart;

      // Convert List<int> to Uint8List to JSArray using toJS
      final uint8List = Uint8List.fromList(bytes);
      await writable.write(uint8List.toJS).toDart;
      await writable.close().toDart;

      debugPrint('WebSync: Wrote $filename (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('WebSync: Write error: $e');
      rethrow;
    }
  }

  /// Reads a file from the synced folder.
  Future<List<int>> readFromFile(String filename) async {
    if (_dirHandle == null) throw Exception('No folder selected');

    try {
      final options = FileSystemGetFileOptions(create: false);
      final handlePromise = _dirHandle!.getFileHandle(filename, options);
      final handle = await handlePromise.toDart;

      final filePromise = handle.getFile();
      final file = await filePromise.toDart;

      final arrayBufferPromise = file.arrayBuffer();
      final arrayBuffer = await arrayBufferPromise.toDart;

      return arrayBuffer.toDart.asUint8List();
    } catch (e) {
      debugPrint('WebSync: Read error: $e');
      rethrow;
    }
  }
}
