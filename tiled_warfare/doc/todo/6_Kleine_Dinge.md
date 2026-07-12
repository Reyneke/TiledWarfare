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
   ⬜ *Umsetzung offen*

   Da Gefechte gerade mit großen Gruppen lange dauern können, soll es eine neue, für alle Objekte nutzbare CombatAction geben: **FocusFire**. Die Aktion wirkt sich wie folgt aus:

   - **Host-Seite:** Alle Tokens, denen es möglich ist, greifen ein vom Host bestimmtes Ziel an.
   - **Spieler-Seite:** Ihm werden alle für ihn angreifbaren Ziele angezeigt. Klickt er ein Ziel an, greifen alle Einheiten, die dazu in der Lage sind (z. B. nicht zu weit entfernt), dieses Ziel gemeinsam an.

   > Diese Änderung ist sowohl in den Regeln zu inkludieren und sinnvoll zu erweitern als auch im Code einzubauen.

9. **Malus für mehrfach angegriffene Tokens**
   ⬜ *Umsetzung offen*

   Jedes Mal, wenn ein Token angegriffen wird, erleidet dieser Token — unabhängig davon, ob er getroffen wurde oder nicht — einen Malus von 5 %. Außerdem gilt er sowohl auf die **Verteidigungswerte** des Tokens als auch als **Bonus für die Angriffswerte** der Tokens, die ihn angreifen.

   **Beispiel:** Ein Zombie, der bereits einmal angegriffen wurde, erleidet auf alle Verteidigungswürfe −5 %, während jeder, der ihn angreift, +5 % auf seinen Angriffswurf bekommt.

   Dieser Malus ist **kumulativ** und gilt bis zum nächsten Zug der Person (Host oder Spieler), die den betroffenen Token kontrolliert.

   > Diese Änderung ist sowohl in den Regeln zu inkludieren und sinnvoll zu erweitern als auch im Code einzubauen.

## Offene Frage

Was gibt es noch zu erledigen auf dem Weg zu einem ersten Prototypen, der unter Windows anderen präsentiert werden soll?
