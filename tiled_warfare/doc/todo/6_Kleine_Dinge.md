# Kleine Dinge

Wie der Name sagt, handelt es sich hier um kleinere Aufgaben, die noch erledigt werden müssen.

## Aufgaben

1. **Scrollende Kamera**
   ✅ Erledigt — Die Karte verwendet bereits `InteractiveViewer` mit `boundaryMargin: EdgeInsets.all(double.infinity)`, sodass gescrollt und gezoomt werden kann.

2. **Kamerafokus auf aktiven Charakter**
   ✅ Erledigt — Bei Linksklick auf einen Charakter wird die Kamera nun sanft auf diesen zentriert.

3. **Tilemap zentrieren**
   ✅ Erledigt — Die Tilemap wird beim Laden nun in der Mitte des Fensters zentriert angezeigt.

4. **Bewegende Host-Tokens**
   ✅ Erledigt — Host-Tokens gleiten nun animiert von Position zu Position statt zu teleportieren.

5. **Charakterbilder als Tokens**
   ✅ Erledigt — Tokens zeigen nun zusätzlich zu den farbigen Punkten das hinterlegte Charakterbild als Overlay an.

6. **Nur ein Donald Trumpster**
   ✅ Erledigt — Es kann nur einen Donald Trumpster geben. Weitere Instanzen erhalten amerikanische Vornamen + "Trumpster" als Nachnamen.

7. **"Zurück"-Button im ScreenGameScreen**
   ✅ Erledigt — Der Zurück-Button zeigt einen Bestätigungsdialog und wertet bei Bestätigung als Sieg für den Host (Niederlage für den Spieler).

8. **Neue CombatAction: FocusFire**
   ✅ Erledigt — FocusFire ist vollständig implementiert:

   - **Spieler-Seite:** Der Spieler kann FocusFire über das Rechtsklick-Kontextmenü (`_showContextMenu`) oder das Info-Panel auswählen. Ihm werden dann alle angreifbaren feindlichen Ziele angezeigt. Klickt er ein Ziel an, greifen alle verfügbaren Einheiten dieses Ziel gemeinsam an.
   - **Host-Seite:** `ObjectHost.performHostFocusFire()` führt taktische FocusFire-Angriffe auf das verwundbarste Spieler-Ziel aus. Wird automatisch eingesetzt, wenn ≥3 Zombies ein Ziel erreichen können oder ein angeschlagener Gegner (woundValue ≤5) existiert.
   - **Kampfregeln:** Abschnitt 5 in `doc/rules/combat_rules.md`.
   - **Bugfix:** `getAvailableActions()` enthielt zuvor keinen Eintrag für `focusFire` → behoben.

9. **Malus für mehrfach angegriffene Tokens**
   ✅ Erledigt — Der kumulative Malus/Bonus ist vollständig implementiert:

   - **Code:** `ObjectToken.timesAttackedThisTurn`, `defenseMalus` (−5 %), `attackBonus` (+5 %).
   - **Reset:** `_resetAllAttackCounters()` zu Beginn jedes neuen Zuges.
   - **Dokumentation:** Abschnitt 6 in `doc/rules/combat_rules.md`.

10. Vollständigkeit aller bisherigen Änderungen und Dokumentation
   ✅ Erledigt — Alle Punkte wurden geprüft und aktualisiert:

   - ✅ **FocusFire** — Bugfix (fehlender `focusFire`-Eintrag in `getAvailableActions()`), Host-Implementierung (`performHostFocusFire`), UI-Integration (Kontextmenü, Host-KI), Regeln dokumentiert.
   - ✅ **Malus-System** — Bereits vollständig implementiert, Regeln in `combat_rules.md` dokumentiert.
   - ✅ **Kampfregeln (`combat_rules.md`)** — Abschnitte 5 (FocusFire) und 6 (Kumulativer Malus/Bonus) hinzugefügt, Abschnittsnummerierung aktualisiert.
   - ✅ **Host-KI** — `ObjectHost.performHostFocusFire()` implementiert, in `widget_caretaker._executeHostAttacks()` taktisch integriert.
   - ✅ **Code-Dokumentation** — Dart-Doc-Kommentare in `ObjectHost`, `ObjectPlayer` und `WidgetCaretaker` ergänzt.
   - ✅ **Integration mit `doc/todo/0_Integration.md`** — Regelkonformität bestätigt, keine weiteren Konflikte.

11. **Visuelle Anzeige des Verletzungsstatus**
   ✅ Erledigt — Die Statusanzeige im ScreenRestaurant wurde deutlich verbessert:

   - **CircleAvatar-Farben:** Statt nur 3 Zuständen (grün/neutral/rot) werden nun 5 abgestufte Farben verwendet:
     - `ready` → grün
     - `reeling` → hellgrün
     - `hurt` → orange
     - `afraid`/`injured` → dunkelorange
     - `dying` → rot
     - `dead`/`overkilled` → grau
   - **Status-Text:** In der Untertitel-Zeile jedes Charakters wird nun der lokalisierte Status-Name angezeigt (z. B. „Benommen", „Verletzt", „Sterbend"), sodass der Spieler ohne Detailansicht den genauen Zustand erkennen kann.
   - **Arzt-Rückmeldung:** Bei Einsatz des Teamarztes wird jetzt eine SnackBar mit Erfolgs- oder Fehlschlag-Meldung eingeblendet – analog zum ScreenCharacterDetail.
   - **Neue Lokalisierungsschlüssel:** `statusReady`, `statusReeling`, `statusHurt`, `statusAfraid`, `statusInjured`, `statusDying`, `statusDead`, `statusOverkilled` in `app_de.arb` und `app_en.arb`.

## Offene Frage

Was gibt es noch zu erledigen auf dem Weg zu einem ersten Prototypen, der unter Windows anderen präsentiert werden soll?