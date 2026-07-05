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
/// Bug reports are maintained in `doc/doc/bug_reports/`.
/// Currently tracked issues:
/// - report_001: Zombie tokens not properly removed upon death
/// - report_002: Zombies stacking on the same hex fields (spawning + movement
///   lack collision checks, causing invisible stacking and log/count mismatch)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}
