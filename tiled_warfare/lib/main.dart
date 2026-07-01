import 'package:flutter/material.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: WidgetMapLoader(),
      ),
    );
  }
}
