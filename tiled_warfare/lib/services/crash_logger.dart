import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Globaler Crash-Logger für den Prototyp.
///
/// Fängt unbehandelte Fehler und Flutter-Exceptions ab,
/// schreibt sie in eine Log-Datei und gibt sie auf der Konsole aus.
///
/// Tester können nach einem Absturz die Datei `logs/crash.log`
/// einsehen und an einen Bug-Report anhängen.
class CrashLogger {
  static final Logger _log = Logger('CrashLogger');
  static File? _logFile;
  static IOSink? _logSink;
  static bool _initialized = false;

  /// Initialisiert das Logging-System.
  ///
  /// [logDir] – Verzeichnis für Log-Dateien (default: `logs/`).
  static Future<void> init({String logDir = 'logs'}) async {
    if (_initialized) return;

    // Logger konfigurieren
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(_onLogRecord);

    // Log-Verzeichnis erstellen
    final dir = Directory(logDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Log-Datei mit Zeitstempel
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    _logFile = File('$logDir/crash_$timestamp.log');
    _logSink = _logFile!.openWrite(mode: FileMode.append);

    // Flutter-Fehler abfangen
    FlutterError.onError = (FlutterErrorDetails details) {
      _log.severe('Flutter-Error', details.exception, details.stack);
      // Auch in der Konsole ausgeben (für Debug-Modus)
      FlutterError.dumpErrorToConsole(details);
    };

    // Plattform-Fehler abfangen (z. B. native Abstürze)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _log.severe('Platform-Error', error, stack);
      return true; // Error als "behandelt" markieren → kein App-Freeze
    };

    _initialized = true;
    _log.info('CrashLogger initialized – log file: ${_logFile!.path}');
  }

  /// Schreibt einen Log-Eintrag und flushed ihn sofort auf die Festplatte.
  static void _onLogRecord(LogRecord record) {
    var message = '${record.level.name} [${record.time}] '
        '${record.loggerName}: ${record.message}';
    
    if (record.error != null) {
      message += '\n  Error: ${record.error}';
    }
    if (record.stackTrace != null) {
      message += '\n  StackTrace: ${record.stackTrace}';
    }

    // Auf Konsole ausgeben
    debugPrint(message);

    // In Datei schreiben
    _logSink?.writeln(message);
    _logSink?.flush();
  }

  /// Protokolliert eine beliebige Nachricht auf INFO-Level.
  static void log(String message) => _log.info(message);

  /// Protokolliert eine Warnung.
  static void warn(String message, [Object? error, StackTrace? stack]) =>
      _log.warning(message, error, stack);

  /// Protokolliert einen Fehler.
  static void error(String message, [Object? error, StackTrace? stack]) =>
      _log.severe(message, error, stack);

  /// Schließt den Log-Sink (z. B. vor App-Ende).
  static Future<void> dispose() async {
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
    _initialized = false;
  }

  /// Gibt den Pfad zur aktuellen Log-Datei zurück.
  static String? get logFilePath => _logFile?.path;
}