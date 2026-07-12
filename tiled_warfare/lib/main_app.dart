import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/screens/screen_start.dart';
import 'package:tiled_warfare/theme/app_theme.dart';

/// Einfacher Locale-Provider als ChangeNotifier.
/// Verwaltet die aktuell ausgewählte Sprache.
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('de');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final LocaleProvider _localeProvider = LocaleProvider();

  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiled Warfare',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: AppTheme.themeModeNotifier.value,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('de'),
        const Locale('en'),
      ],
      locale: _localeProvider.locale,
      home: ScreenStart(localeProvider: _localeProvider),
    );
  }
}