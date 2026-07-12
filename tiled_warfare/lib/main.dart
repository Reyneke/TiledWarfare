import 'package:flutter/material.dart';
import 'package:tiled_warfare/main_app.dart';

/// Entry point for the TiledWarfare application.
///
/// Initializes Flutter bindings if needed (e.g., for async operations
/// such as loading assets or plugins before [runApp]) and launches the
/// root [MainApp] widget.
///
/// For project-wide documentation, see the `doc/` directory which contains
/// class diagrams, sequence diagrams, dependency graphs, and summaries
/// designed to help new contributors onboard quickly.
///
/// Bug reports are maintained in `doc/bug_reports/`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}
