import 'package:flutter/material.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

class ScreenMain extends StatelessWidget {
  const ScreenMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiled Warfare'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeModeNotifier,
            builder: (context, themeMode, child) {
              return IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                tooltip: themeMode == ThemeMode.dark
                    ? 'Switch to Light Theme'
                    : 'Switch to Dark Theme',
                onPressed: () {
                  AppTheme.themeModeNotifier.value =
                      themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: const WidgetMapLoader(),
    );
  }
}
