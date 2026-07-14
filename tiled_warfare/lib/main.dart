import 'package:flutter/material.dart';
import 'package:tiled_warfare/main_app.dart';
import 'package:tiled_warfare/services/crash_logger.dart';

/// Entry point for the TiledWarfare application.
///
/// Initializes Flutter bindings, the global crash-logger, and launches
/// the root [MainApp] widget.
///
/// For project-wide documentation, see the `doc/` directory which contains
/// class diagrams, sequence diagrams, dependency graphs, and summaries
/// designed to help new contributors onboard quickly.
///
/// Bug reports are maintained in `doc/bug_reports/`.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLogger.init();
  runApp(const MainApp());
}
