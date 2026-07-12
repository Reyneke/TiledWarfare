import 'package:flutter/material.dart';

/// Einfacher Locale-Provider als [ChangeNotifier].
/// Verwaltet die aktuell ausgewählte Sprache.
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('de');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}

/// Ein [InheritedNotifier]-Wrapper, der [LocaleProvider] durch den Widget-Baum
/// propagiert. Jeder Widget-Teilbaum kann mit `LocaleProviderWidget.of(context)`
/// auf den Provider zugreifen und wird automatisch neu gebaut, wenn sich die
/// Sprache ändert.
class LocaleProviderWidget extends InheritedNotifier<LocaleProvider> {
  const LocaleProviderWidget({
    super.key,
    required LocaleProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// Gibt den [LocaleProvider] aus dem nächstgelegenen `LocaleProviderWidget`
  /// im Widget-Baum zurück. Wirft einen Fehler, falls keiner existiert.
  static LocaleProvider of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<LocaleProviderWidget>();
    assert(widget != null, 'No LocaleProviderWidget found in context');
    return widget!.notifier as LocaleProvider;
  }
}