import 'package:flutter/services.dart';

/// A document handed over by Android (intent, picker or share sheet).
class OpenedFile {
  const OpenedFile({required this.name, required this.content, this.uri});

  final String name;
  final String content;

  /// content:// or file:// URI to save back to; null for shared text.
  final String? uri;
}

class FileBridgeException implements Exception {
  const FileBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the platform channel implemented in MainActivity.kt.
class FileBridge {
  FileBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('markdown_viewer/file');

  final MethodChannel _channel;

  /// Called when another app opens a file while this one is running.
  void setOnFileOpened(
    void Function(OpenedFile file) onFile, {
    required void Function(Object error) onError,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onFileOpened') return;
      try {
        onFile(_toFile(call.arguments));
      } on FileBridgeException catch (e) {
        onError(e);
      }
    });
  }

  /// The file the app was launched with, if any.
  Future<OpenedFile?> getInitialFile() async =>
      _toFileOrNull(await _channel.invokeMethod<Object?>('getInitialFile'));

  /// Shows the system file picker. Returns null if cancelled.
  Future<OpenedFile?> openDocument() async =>
      _toFileOrNull(await _channel.invokeMethod<Object?>('openDocument'));

  Future<void> saveFile(String uri, String content) =>
      _channel.invokeMethod<void>('saveFile', {'uri': uri, 'content': content});

  /// Shows the system "Save as" dialog and writes [content] there.
  /// Returns the chosen file's name and URI, or null if cancelled.
  Future<({String name, String uri})?> createDocument(
    String suggestedName,
    String content,
  ) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'createDocument',
      {'name': suggestedName, 'content': content},
    );
    if (result == null) return null;
    return (name: result['name'] as String, uri: result['uri'] as String);
  }

  /// Opens [url] in another app (browser, mail, ...). Returns false if no
  /// app can handle it.
  Future<bool> openUrl(String url) async =>
      await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;

  /// Opens the system print dialog for [html] (which offers "Save as PDF").
  /// [name] is the print job name, used as the default PDF file name.
  Future<void> printHtml(String name, String html) =>
      _channel.invokeMethod<void>('printHtml', {'name': name, 'html': html});

  OpenedFile? _toFileOrNull(Object? raw) => raw == null ? null : _toFile(raw);

  OpenedFile _toFile(Object? raw) {
    final map = (raw as Map).cast<String, Object?>();
    final error = map['error'];
    if (error != null) throw FileBridgeException(error.toString());
    return OpenedFile(
      name: map['name'] as String? ?? 'Document.md',
      content: map['content'] as String? ?? '',
      uri: map['uri'] as String?,
    );
  }
}
