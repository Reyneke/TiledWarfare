import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';
import 'package:tiled_warfare/widgets/widget_caretaker.dart';

/// Widget-Test: Die Combat-Maneuver-Buttons (Nahkampf, Fernkampf, FocusFire)
/// im Info-Panel des WidgetCaretaker müssen klickbar sein.
///
/// Regressionstest für den Bug "Combat Maneuvers Buttons funktionieren nicht":
/// Das Info-Panel lag vorher bei Stack-Position -232 außerhalb der
/// Stack-Bounds des gepaddeten WidgetCaretaker. RenderBox.hitTest lehnt
/// Positionen außerhalb der Bounds ab (Clip.none erlaubt nur das Malen über
/// die Grenzen, nicht das Hit-Testen) – die Buttons waren dadurch physisch
/// nicht klickbar. Der WidgetCaretaker erhält jetzt die volle Fläche, die
/// Karte ist intern gepaddet, und die Panels liegen bei left: 8 / right: 8
/// innerhalb der Stack-Bounds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHarness() {
    final hexGrid = HexGrid(
      tileWidth: 32, tileHeight: 32, mapWidth: 30, mapHeight: 30,
    );
    // ObjectHost.hexGrid ist ein late-Feld, das im echten Spielfluss von
    // ScreenMain._onMapLoaded gesetzt wird. Im Test-Harness muss es manuell
    // gesetzt werden, damit der Host-Zug (Runden-Start) nicht crasht.
    ObjectHost().hexGrid = hexGrid;
    return MaterialApp(
      home: Scaffold(
        body: WidgetCaretaker(
          hexGrid: hexGrid,
          // Identity-Transformation: Karte bei (0,0), Skalierung 1
          transformationController: TransformationController(),
        ),
      ),
    );
  }

  testWidgets('Combat-Maneuver-Buttons sind sichtbar und klickbar',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pump();

    // Das WidgetCaretaker initialisiert 3 Line Cooks (Fallback, wenn die
    // unitList leer ist) und startet Runde 1. Wir warten auf den
    // post-frame-callback und die Runden-Initialisierung.
    await tester.pump(const Duration(milliseconds: 50));

    // Info-Panel ist initial nicht sichtbar (kein Token ausgewählt)
    expect(find.text('Nahkampf'), findsNothing);

    // Einen Spieler-Token auswählen: Tipp auf die Kartenposition des ersten
    // Line Cooks. Dessen Position liegt im Kartenbereich (links oben),
    // die Karte ist intern um 240px nach rechts gepaddet – die Token-Position
    // ist also bei Bildschirm-x ≈ 240 + TokenPosition.
    final firstCook = ObjectPlayer().unitList; // sichere Referenz
    final cook = firstCook.isNotEmpty ? firstCook.first : null;
    if (cook == null) {
      // Kein Token verfügbar (Sollte nicht passieren – Fallback erzeugt 3)
      return;
    }
    final tokenScreenX = 240 + cook.position.dx;
    final tokenScreenY = cook.position.dy;
    await tester.tapAt(Offset(tokenScreenX, tokenScreenY));
    await tester.pump();

    // Info-Panel mit Combat-Maneuver-Buttons erscheint
    expect(find.text('Nahkampf'), findsOneWidget,
        reason: 'Info-Panel mit Nahkampf-Button muss nach Token-Auswahl sichtbar sein');

    // "Nahkampf"-Button antippen – der Klick muss den Button erreichen
    await tester.tap(find.text('Nahkampf'));
    await tester.pump();

    // Erwartung: Der Targeting-Modus wurde aktiviert (kein Fehler, kein
    // Verschwinden des Panels). Wenn der Klick NICHT den Button erreichte
    // (alter Bug), würde _handleTap die Kartenposition treffen, keinen
    // Token finden und das Panel schließen.
    expect(find.text('Nahkampf'), findsOneWidget,
        reason: 'Info-Panel muss nach Button-Klick weiterhin sichtbar sein');
    expect(tester.takeException(), isNull,
        reason: 'Kein Exception nach Button-Klick');
  });
}