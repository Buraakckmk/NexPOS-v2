import "dart:io";

import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";

class LocalErrorLogService {
  LocalErrorLogService._();

  static final LocalErrorLogService instance = LocalErrorLogService._();
  static const String _fileName = "adisyon_error_log.txt";
  static bool _disabled = false;

  Future<File> _resolveFile() async {
    try {
      if (Platform.isWindows) {
        final dir = await getTemporaryDirectory();
        await dir.create(recursive: true);
        return File("${dir.path}${Platform.pathSeparator}$_fileName");
      }
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      return File("${dir.path}${Platform.pathSeparator}$_fileName");
    } catch (_) {
      final dir = await getTemporaryDirectory();
      await dir.create(recursive: true);
      return File("${dir.path}${Platform.pathSeparator}$_fileName");
    }
  }

  Future<void> log({
    required String source,
    required String message,
    String? details,
    StackTrace? stackTrace,
  }) async {
    if (_disabled) return;
    try {
      final file = await _resolveFile();
      final now = DateTime.now().toIso8601String();
      final buffer = StringBuffer()
        ..writeln("[$now] source=$source")
        ..writeln("message=$message");

      if (details != null && details.trim().isNotEmpty) {
        buffer.writeln("details=$details");
      }

      if (stackTrace != null) {
        buffer.writeln("stack=$stackTrace");
      }

      buffer.writeln("---");

      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (error) {
      _disabled = true;
      if (kDebugMode) {
        debugPrint("[local-log-write-failed] $error");
      }
    }
  }
}
