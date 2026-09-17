# Karrierepfade

Dieses Dokument ersetzt den bisherigen, unredigierten Wikipedia-Auszug zur **Küchenbrigade**
(https://en.wikipedia.org/wiki/Kitchen_brigade) durch eine **nach Rang geordnete Referenztabelle**
(englischer Titel / französischer Titel / Verantwortlichkeiten) und leitet daraus einen **Vorschlag für
Karrierepfade im Spiel** ab (Klassen, Ränge, Kosten, Aufstieg). Es knüpft an `0-Base.md` (V1–V9) und
`9_Personal.md` (Personal, Attribute & Persönlichkeit) an.

> **Zur Quelle:** Die Referenztabelle fasst den Wikipedia-Artikel zusammen; die Verantwortlichkeiten sind
> sinngemäß ins Deutsche übertragen. Die ursprünglichen Einzelnachweise des Artikels stehen im Anhang.

## Aktueller Stand

- Im Spiel existieren bisher nur **zwei** kämpfende Personal-Klassen: `ObjectApprentice` (Lehrling) und
  `ObjectLineCook` (Line Cook). `ObjectLineCook` ist eine Unterklasse von `ObjectApprentice`
  (`lib/objects/player_objects/`).
- Der einzige Aufstieg ist **Lehrling → Line Cook** (`ObjectProfile.upgradeToLineCook`, 500 € ab Level 5,
  `EconomyBalance.lineCookPromotionLevel`). Weitere Ränge fehlen.
- Teamärzte sind ein **eigener, nicht kämpfender** Personaltyp (`ObjectTeamMedic`).
- Alle Balance-Werte liegen zentral in `EconomyBalance` (V7); es gibt **keine** magischen Zahlen im Fluss.
- `upgradeToLineCook` erzeugte früher ein **frisches** `ObjectLineCook` und verlor dabei Identität/Name; mit
  V9 (`9_Personal.md`) werden Identität (`StaffData.id`), Persönlichkeit und Ressourcen bei der Beförderung
  erhalten.

## Referenztabelle (nach Rang)

Rang 1 = höchste Position. „Unter-Rang(e)“ nennt spezialisierte Unterpositionen, die in größeren Küchen den
jeweiligen Postenchef ergänzen (kein eigenständiger Rang, sondern eine Aufteilung desselben Postens).

| Rang | Englischer Titel | Französischer Titel | Verantwortlichkeiten | Unter-Rang(e) |
|---:|---|---|---|---|
| 1 | Kitchen chef | Chef de cuisine | Gesamtleitung der Küche: führt das Personal, erstellt Menüs und neue Rezepte (mit dem Restaurantleiter), kauft Rohware ein, bildet Lehrlinge aus und sorgt für Sauberkeit und Hygiene. | – |
| 2 | Deputy / second kitchen chef | Sous-chef de cuisine | Nimmt Anweisungen direkt vom Chef de cuisine entgegen, leitet die Küche in dessen Abwesenheit und vertritt ihn. | – |
| 3 | Senior chef / station chief | Chef de partie | Leitet einen Küchenposten und spezialisiert sich auf dessen Gerichte; untergeordnete Posten heißen Demi-chef. | Demi-chef |
| 4 | Sauce maker / sauté cook | Saucier | Bereitet Saucen und warme Hors d'œuvres zu, vollendet Fleischgerichte; in kleineren Häusern auch Fisch und Sauté-Gerichte. Höchster Posten der Stationen. | – |
| 5 | Fish cook | Poissonnier | Bereitet Fisch- und Meeresfrüchtegerichte zu, oft inkl. Fischzerlegung und der zugehörigen Saucen. | – |
| 6 | Roast cook | Rôtisseur | Leitet ein Team, das Gerichte brät, grilliert und frittiert. | Grillardin (Grill), Friturier (Frittiertes) |
| 7 | Entrée preparer | Entremétier | Bereitet Suppen und Gerichte ohne Fleisch/Fisch zu, inkl. Gemüse- und Eiergerichte (ursprünglich „entremets“). | Potager (Suppen), Légumier (Gemüse) |
| 8 | Pantry supervisor | Garde manger | Kalte Hors d'œuvres, Pâtés, Terrinen und Aspik, Salate, große Buffet-Präsentationen sowie Charcuterie. | Charcutier (Wurst-/Fleischwaren) |
| 9 | Pastry cook | Pâtissier | Bereitet Desserts und Süßspeisen zu; ohne Boulanger auch Brot und Backwaren, ggf. Pasta. | Confiseur, Glacier, Décorateur, Boulanger, Chocolatier, Fromager |
| 10 | Spare hand / roundsman | Tournant | Springt in der Küche zwischen den Posten und unterstützt, wo Not am Mann ist. | – |
| 11 | Butcher | Boucher | Zerlegt Fleisch, Geflügel und teils Fisch; kann mit der Paniervorbereitung betraut sein. | – |
| 12 | Expediter / announcer | Aboyeur | Nimmt Bestellungen aus dem Gastraum an und verteilt sie an die Posten; kann auch vom Sous-chef übernommen werden. | – |
| 13 | Staff cook | Communard | Bereitet die Mahlzeiten für das Restaurantpersonal zu. | – |
| 14 | Cook | Cuisinier | Eigenständige Position; bereitet i. d. R. bestimmte Gerichte an einem Posten zu. | Demi-chef |
| 15 | Junior / assistant cook | Commis | Arbeitet an einem Posten, berichtet direkt an den Chef de partie und pflegt das Arbeitsgerät des Postens. | – |
| 16 | Apprentice | Apprenti(e) | Auszubildende(r): theoretische/praktische Ausbildung und Küchenerfahrung; übernimmt Vorbereitungs- und Reinigungsarbeiten. | – |
| 17 | Kitchen boy | Garçon de cuisine | In größeren Häusern Vorbereitungs- und Hilfsarbeiten zur Unterstützung. | – |
| 18 | Busser | Commis de débarrasseur | Räumt Tische ab, bringt schmutziges Geschirr zum Spüler, deckt Tische und füllt auf. | – |
| 19 | Dishwasher / kitchen porter | Plongeur | Reinigt Geschirr und Utensilien und übernimmt einfache Vorbereitungsarbeiten. | Marmiton (Töpfe und Pfannen) |

**Annahme zur Rangfolge:** Die Küchenbrigade ist historisch gewachsen und nicht in allen Quellen eindeutig
strikt geordnet. Die Tabelle folgt der üblichen Lesart (Küchenleitung → Postenchefs der Stationen → Ränge
innerhalb einer Station → Hilfs- und Serviceposten). Innerhalb der Stationen gilt der `Saucier` als höchster
Posten. Diese Reihenfolge ist eine bewusste, dokumentierte Setzung für die Rangskala des Spiels.

## Spiel-Design: Karrierepfade

Die Referenztabelle dient als Vorbild. In das Spiel übertragen wird daraus eine **Aufstiegsleiter** mit
zwei Achsen:

1. **Vertikal (Rang):** eine durchgängige Beförderungskette Lehrling → Line Cook → Chef de partie →
   Sous-chef → Chef de cuisine, gesteuert über Level-Gates und Kosten (wie der bestehende
   Lehrling → Line-Cook-Aufstieg).
2. **Horizontal (Station):** nach Erreichen des Postenchef-Rangs wählt der Charakter eine **Station**
   (Saucier, Poissonnier, Rôtisseur, Entremétier, Garde manger, Pâtissier) und erhält deren Spezial-Bonus.

**Begriffsklärung „Station":** In der Küchenbrigade ist eine *Station* der **räumliche Zuständigkeitsbereich
eines Chef de partie** (z. B. die Saucier-Station oder die Bratstation). Im Spiel ist die Station die
**horizontale Spezialisierung**, die ein Charakter **nach Erreichen des Rangs Chef de partie** wählt
(Saucier, Poissonnier, Rôtisseur, Entremétier, Garde manger, Pâtissier). Sie ist **kein Rang und keine
Klasse**, sondern ein Bündel aus Modifikatoren (inkl. Aura). Die Unterränge der Referenztabelle sind
**Varianten** einer Station (z. B. Grillardin/Friturier der Bratstation).

### 1. Aufstiegsleiter (vertikal)

Alle Werte sind **Vorschläge und Tuning-Werte**, die in `EconomyBalance` liegen (V7). `UnitStats` folgt der
bestehenden Konvention (`apprenticeStats` 40/20/6/2/3, `lineCookStats` 80/40/3/2/3).

| Stufe | Brigade-Rang (FR) | Spielklasse | Voraussetzung | Kosten | UnitStats (ATK/DEF/MOV/DMG/RNG) |
|---:|---|---|---|---|---|
| 0 | Plongeur / Commis | *keine Kampfklasse* – Hilfsrolle (s. § 3) | – | 50 € (Anheuern) | – |
| 1 | Apprenti | `ObjectApprentice` (vorhanden) | – | 100 € (`hireApprenticeCost`) | 40/20/6/2/3 |
| 2 | Cuisinier | `ObjectLineCook` (vorhanden) | Level 5 (`lineCookPromotionLevel`) | 500 € (`upgradeToLineCookCost`) | 80/40/3/2/3 |
| 3 | Chef de partie | `ObjectChefDePartie` (neu) | Level 10 | 1.200 € | 110/55/3/3/3 |
| 4 | Sous-chef | `ObjectSousChef` (neu) | Level 15 | 3.000 € | 140/70/3/4/3 |
| 5 | Chef de cuisine | `ObjectHeadChef` (neu; **aktiv** = Management / **formell** = Kampf) | Level 20 | 8.000 € | aktiv: *kein Kampfprofil* + Management-Buff (s. u.) · formell: 160/80/2/5/3 |

- **Neue Level-Gates** gehören neben `lineCookPromotionLevel` in `EconomyBalance`
  (z. B. `chefDePartiePromotionLevel`, `sousChefPromotionLevel`, `headChefPromotionLevel`) und werden in
  `balance_sanity_test.dart` als monoton steigende Kette abgesichert.
- **Beförderung erhält Identität.** Wie in V9 muss der Aufstieg **im selben Objekt** erfolgen
  (`id`, `personalityId`, Ressourcen, `matchHistory`, Wundstatus bleiben erhalten) – der frühere
  `upgradeToLineCook`-Fehler (frisches Objekt) darf sich nicht wiederholen.
- **Chef de cuisine ist eine Doppelrolle (aktiv / formell).**
  - **Aktiv (zugeordnet):** nahezu nicht kämpfend; führt das Restaurant an und bufft die **drei Werte des
    passiven Einkommens** (Attraktivität, Kundenzufriedenheit, Kapazität – s. `team_rules.md`
    „Einnahmequellen“ und `2-Wirtschaftsschleife.md` § 8).
  - **Formell (nicht zugeordnet):** bleibt eine **kämpfende** Einheit mit den Stat-Boni der Aufstiegsleiter,
    aber **ohne** die Mali/Boni eines aktiven Chef de Cuisine; rückt **automatisch nach**, sobald der aktive
    ausfällt.
  Er ist **nicht** der Besitzer/Spielercharakter (`9_Personal.md` führt den Spielercharakter außerhalb des
  Personalumfangs). Pro Restaurant ist **höchstens ein aktiver** Chef de Cuisine möglich (Unikat-Invariante, § 6).

### 2. Stationen (horizontal)

Nach dem Rang **Chef de partie** wählt ein Charakter eine Station. Die Station ist kein eigener Rang,
sondern eine **Spezialisierung** mit Stat-/Fähigkeits-Bonus; die Grundwerte bleiben die der Stufe 3.

**Aura (einmalig definiert):** Alle Stations-Boni wirken auf den Charakter selbst **und** zusätzlich als
Aura auf **verbündete Einheiten** innerhalb `Aura-Radius` Hexfeldern um ihn (Cube-Distanz ≤ Radius,
`HexGrid.distance`). Der Radius **skaliert mit dem Rang**: Chef de partie = 1, Sous-chef = 2,
Chef de cuisine = 3. Ausnahme: **Pâtissier** – reine Support-Station **ohne** Kampf-Aura. Für den
Chef de cuisine gilt der Radius **nur in der formellen (kämpfenden) Rolle**; der aktive Chef steht nicht im
Gefecht, seine Aura ist damit gegenstandslos.

| Station (FR) | Titel (EN) | Variante von | Spezialisierung (selbst + Aura-Radius) |
|---|---|---|---|
| Saucier | Sauté chef | – | Höchster Posten: Bonus auf Angriff/Zielwert (W100). |
| Poissonnier | Fish cook | – | Bonus auf Fernkampf/Reichweite; verbessert Fisch-Zerlegung (Loot/Beute). |
| Rôtisseur | Roast cook | – | Bonus auf Schaden. |
| Grillardin | Grill cook | Rôtisseur | Bonus auf Schaden und Nahkampfangriffe. |
| Friturier | Fry cook | Rôtisseur | Bonus auf Schaden und Fernkampfangriffe. |
| Entremétier | Entrée preparer | – | Bonus auf Verteidigung (robuste „Allrounder“-Station). |
| Potager | Soup cook | Entremétier | Bonus auf Suppen-/Flächenwirkung. |
| Légumier | Vegetable cook | Entremétier | Bonus auf Gemüse-/Zutateneffekte. |
| Garde manger | Pantry chef | – | Bonus auf Verteidigung/LP-nahe Effekte (kaltblütig, schwer aus der Ruhe zu bringen). |
| Charcutier | Charcuterie specialist | Garde manger | Bonus auf Charcuterie-/Dauerwirkung (Terrinen, Confit). |
| Pâtissier | Pastry chef | – | Support-Station: verbessert Moral/Wochen-Refill der Kollegen (keine Kampf-Aura). |

- Die Stationen sind der **leichte Weg** zum Ausbau der Vielfalt: keine neuen Kampfklassen, sondern
  **Modifikatoren** auf den bestehenden Postenchef-Werten (analog zu den Persönlichkeits-Modifikatoren aus
  V9, gedeckelt über `EconomyBalance`).
- **Unterränge aus der Referenztabelle werden als Varianten abgebildet:** Grillardin/Friturier →
  `Rôtisseur`, Potager/Légumier → `Entremétier`, Charcutier → `Garde manger`. Eine Variante ist wählbar,
  sobald die Basis-Station gewählt wurde, und **ersetzt** deren Bonus (kein Stapeln).
- **Aura-Auswertung:** Eine Einheit ist betroffen, wenn `HexGrid.distance(...)` zur Aura-Quelle
  ≤ `Aura-Radius` ist. Default sind **Verbündeten-Buffs**; **Debuff-Auren sind möglich** und wirken derzeit
  gegen **beide** Gegner-Kategorien (*Minion* **und** *Bossmonster*), nicht nach Monstertyp
  (s. „Entscheidungen“).
- Der `Demi-chef` (Rang 3, Unterrang) ist als **Vorstufe der Station** nutzbar: Ein Demi-chef arbeitet an
  einer Station, ohne deren vollen Bonus zu erhalten.

### 3. Hilfs- und Service-Rollen (nicht/schwach kämpfend)

Diese Ränge geben dem Management Tiefe, ohne die Kampfklassen aufzublähen. Sie sind mit **Wirkung auf die
Management-Schleife** gedacht (`2-Wirtschaftsschleife.md`), **nicht** als Frontkämpfer: Sie ziehen **nicht**
in den Kampf und werden **auf derselben Seite wie die Teamärzte** geführt (`ScreenHireAndFire`). Alle Rollen
sind anstellbar und kosten **wöchentlich** Lohn (s. „Entscheidungen“).

| Brigade-Rang (FR) | Titel (EN) | Spielwirkung (Vorschlag) | Lohn (wöchentlich) |
|---|---|---|---|
| Communard | Staff cook | Beschleunigt/verbessert den Wochen-Refill von Vitalität und Moral (V9 § 2). | mittel |
| Tournant | Roundsman | Reduziert den kumulativen Erschöpfungs-Malus der Nulltage (V9 § 6). | gering |
| Aboyeur | Expediter | Verbessert den Bestellfluss bzw. das „Kunden/Woche“-Fuzzy-Modell (`EconomyBalance`, § 8). | mittel |
| Plongeur / Marmiton | Dishwasher / porter | Grundreinigung: senkt laufende Betriebskosten. | gering |
| Commis de débarrasseur | Busser | Service-Hilfe: leicht positiver Attraktivitäts-Effekt. | gering |
| Boucher | Butcher | Ermöglicht die Paniervorbereitung; wirkt auf Nachschub/Beute. | gering |
| Garçon de cuisine | Kitchen boy | Allgemeine Vorbereitung: kleiner Bonus auf alle Tätigkeiten. | gering |

### 4. Einbindung in bestehende Systeme

- **`EconomyBalance` (V7):** neue Level-Gates, Kosten, `UnitStats`-Profile und Stations-Bonusse liegen
  ausschließlich hier; keine Literale in `lib/screens/` oder `lib/objects/`.
- **Aura (neu):** Stations-Auren sind ein **neues** Kampfmerkmal – im Code existiert bisher **keine**
  Aura-/Buff-Mechanik. Aura-Radius je Rang und Bonus je Station liegen als `EconomyBalance`-Werte
  (z. B. `stationAuraRadiusByRank`); die Auswertung nutzt die vorhandene Hex-Distanz
  (`HexGrid.distance(...) ≤ Aura-Radius`, Cube-Distanz). Default sind Verbündeten-Buffs; Debuff-Auren
  gegen Gegner-Kategorien (*Minion* / *Bossmonster*) sind möglich.
- **`StaffData` / Persistenz (V6):** Der Rang wird über einen **stabilen Rang-/Klassen-Schlüssel**
  persistiert (nicht über den Anzeigenamen), damit Fehlbenennungen keinen stillen Rangwechsel auslösen.
  Neue Felder nur **additiv und tolerant** (Defaults bei Alt-Spielständen).
- **Zuteilung & Rolle (V6):** Die Chef-de-cuisine-Doppelrolle wird persistiert – z. B. `headChefRole`
  (`aktiv`/`formell`) und `assignedRestaurantId` in `StaffData`, additiv/tolerant. So übersteht die
  aktiv/formell-Unterscheidung Speichern und Restaurant-Wechsel.
- **`ObjectApprentice`/`ObjectLineCook`:** als Basis der Aufstiegsleiter beibehalten; neue Ränge als
  Unterklassen (z. B. `ObjectChefDePartie`) analog zu `ObjectLineCook`.
- **`EconomyService`:** reine Funktionen für Aufstiegskosten und Zulässigkeit (`canAfford`, Level-Gate) –
  der bestehende Aufstiegspfad wird auf dieselbe API umgestellt.
- **Teamärzte** bleiben ein **separater** Personaltyp; sie sind keine Brigade-Ränge. Die
  **Hilfs-/Service-Rollen** aus § 3 werden **auf derselben Seite** verwaltet wie die Teamärzte
  (`ScreenHireAndFire`) und ziehen nicht in den Kampf.
- **Lohn/Unterhalt (beschlossen):** **alle** Brigade-Ränge kosten **wöchentlich** Lohn – analog zur
  Teamarzt-Abrechnung (`EconomyService.weeklyMedicCost`: Basis + Anteil je Teammitglied). Das erweitert die
  Wirtschaftsschleife (`2-Wirtschaftsschleife.md`, V8-Wochentick) und macht das Personal zu einem
  **laufenden** Posten.

### 5. Namensgebung (Französisch vs. Italienisch)

- Die Charaktere tragen aktuell italienisch geprägte Namen (`RandomNames`, `Cuisine`), die Brigade-Titel sind
  französisch. Der **französische Titel** wird daher als **angezeigter Rang** verwendet (reiner Anzeigetext),
  während die **interne Klasse** einen englischen Dart-Namen erhält (`ObjectChefDePartie`).
- Die Rang-Anzeigenamen werden über `l10n` lokalisiert (DE/EN), wie in `9_Personal.md` Phase 7 eingeführt.

### 6. Balance & Konventionen

- Alle Zahlen in diesem Dokument sind **Tuning-Vorschläge**. Verbindlich ist allein `EconomyBalance`.
- `balance_sanity_test.dart` sichert ab: monotone Aufstiegskette (Kosten und Level steigen), Stat-Werte je
  Rang steigen in ATK/DEF, Stations-Bonusse sind gedeckelt.
- `balance_sanity_test.dart` prüft zusätzlich: der Aura-Radius steigt **monoton** mit dem Rang
  (Chef de partie = 1 → Sous-chef = 2 → Chef de cuisine = 3); Aura-Bonusse sind gedeckelt.
- **Unikat-Invariante:** pro Restaurant höchstens **ein aktiver (zugeteilter)** `Chef de cuisine` – nicht
  überschreitbar durch Anheuern oder Befördern. **Formelle** Chef de Cuisine sind als kämpfende Titelträger
  **unbegrenzt** möglich. Das **automatische Nachrücken** des formellen Chefs beim Ausfall des aktiven ist
  Teil der Invariante; Regel und Zuteilung sind persistiert und im Balance-Test abgesichert.
- Aufstiege dürfen das Budget nur bis `EconomyBalance.negativeLimit` belasten (`canAfford`).

## Entscheidungen (getroffen)

- **`Chef de cuisine` = Doppelrolle (aktiv / formell).** Es gibt pro Restaurant **höchstens einen aktiven**
  Chef de Cuisine, der dem Restaurant **zugeteilt** ist und es führt: Er bufft die **drei Werte des passiven
  Einkommens** (Attraktivität, Kundenzufriedenheit, Kapazität) und ist zu wichtig für den ständigen
  Kampfeinsatz (Management-Profil, **kein** Kampfprofil). Ein Chef de Cuisine **ohne Zuteilung** ist ein
  **formeller Chef de Cuisine**: Er bleibt eine **kämpfende** Einheit mit allen Stat-Boni der Aufstiegsleiter –
  **ohne** die Mali/Boni eines aktiven Chef de Cuisine – und **rückt automatisch nach**, sobald der aktive
  ausfällt. Er ist **nicht** der Spielercharakter/Besitzer.
- **Stations-Wahl:** **einmalig bindend**, mit **kostenpflichtigem Wechsel** (siehe § 2).
- **Wöchentliche Löhne:** ja – **alle** Brigade-Ränge kosten laufend Geld (nicht nur einmalig), analog zur
  Teamarzt-Abrechnung (`weeklyMedicCost`: Basis + Anteil je Teammitglied).
- **Hilfs-/Service-Rollen:** **alle** anstellbar; sie ziehen **nicht** in den Kampf und werden **auf
  derselben Seite wie die Teamärzte** geführt (`ScreenHireAndFire`).
- **Namensraum:** Französische Ränge sind **reine Anzeige**; interne Dart-Klassen erhalten englische Namen
  (siehe § 5).
- **Aura-Ziel:** Verbündeten-Buffs sind der Default; **Debuff-Auren sind möglich** und wirken **derzeit gegen
  beide** Gegner-Kategorien (*Minion* **und** *Bossmonster*) – nicht nach Monstertyp. Eine getrennte
  Zuordnung (Station → Kategorie) ist ein möglicher späterer Ausbau, aber **kein** jetziges Ziel.
- **Gegner-Kategorien:** bestätigt – nur *Minion* (z. B. Dough Zombie) und *Bossmonster* (z. B. Dough
  Dumpster) existieren.
- **Nachrück-Auslöser:** „ausfällt“ = **Tod, Entlassung oder Transfer** in ein anderes Restaurant
  (Transfer s. „Personal Transfer“).
- **Nachrücker-Auswahl:** zwischen **höchstem Level** und **ältester Anstellung** – **in Rücksprache mit dem
  Spieler** (der Spieler entscheidet/bestätigt den Nachrücker).
- **Reversibilität:** **einseitig** – wer einmal aktiv war, wird nicht wieder formell. Einzige Option:
  **Neustart des Charakters bei Level 0**.
- **Transfer-Kostenmodell:** **rang-/levelgestaffelt** (`transferCostBase` + `transferCostPerLevel` in
  `EconomyBalance`), und **das Ziel-Restaurant zahlt** („Anwerbeprämie“).
- **Transfer-Wirksamkeit:** der Transfer wird **erst beim nächsten Speichern** wirksam; kann das zahlende
  Restaurant die Voraussetzung (`canAfford`) nicht erfüllen, wird der Transfer **sofort abgelehnt**.

## Personal Transfer

**Ziel:** Charaktere zwischen den **eigenen** Restaurants gegen Geld verschieben. Die **Identität bleibt
vollständig erhalten** (V9: `id`, Persönlichkeit, Rang, Level, XP, Match-Historie, Ressourcen, Wundstatus).

**Wie es funktioniert.** Restaurants sind eigenständige Spielstände (V1). Ein Transfer ist damit ein **Umzug
eines Charakters von `RestaurantData A.staff` nach `RestaurantData B.staff`** – beide liegen im selben
`ProfileData`. `ObjectProfile` hält nur das **aktive** Restaurant; der Transfer läuft daher über das
vorhandene **Merging** (`toProfileData()` ersetzt beide Restaurants per `id` in einem Schreibvorgang).
Genau dieser in `0-Base.md` noch offene Punkt („Merging beim Speichern“) wird damit von einem Randfall zu
einem Muss.

### Regeln

| Aspekt | Regel |
|---|---|
| **Kosten** | **rang-/levelgestaffelt**: `EconomyBalance.transferCostBase` + `transferCostPerLevel`; Prüfung mit `EconomyService.canAfford`. Werte sind Tuning (V7). |
| **Wer zahlt** | das **Ziel-Restaurant** („Anwerbeprämie“) – **beschlossen**. |
| **Wirksamkeit** | **erst beim nächsten Speichern**; kann das zahlende Restaurant `canAfford` nicht erfüllen, wird der Transfer **sofort abgelehnt** (kein Teileffekt). |
| **Identität** | Vollständig erhalten (V9) – inkl. `matchHistory`, Ressourcen und Wundstatus. |
| **Chef de Cuisine** | Transfer eines **aktiven** Chefs = „Ausfall“ im Quell-Restaurant → **sofortiges Nachrücken** (s. „Entscheidungen“). Im Ziel-Restaurant wird er **formell**, falls dort schon ein aktiver existiert; sonst kann er dort aktiv zugeteilt werden. `headChefRole`/`assignedRestaurantId` werden neu gesetzt. |
| **Einschränkungen** | Nur zwischen Restaurants **desselben Profils**; kein Transfer in ein **aufgelöstes** Restaurant; nicht während eines Gefechts. |
| **Persistenz (V6)** | Additiv/tolerant; Quell- und Ziel-Liste werden im selben Speichervorgang (Merge) geschrieben. |

### UI

Neue Aktion **„Verschieben nach …“** auf der Personal-Seite (neben bzw. in `ScreenHireAndFire`): Auswahl des
Ziel-Restaurants aus den Restaurants des Profils, Bestätigungsdialog mit den Kosten.

## Offene Folgepunkte

Beim Umsetzen verbleiben **keine offenen Design-Fragen** mehr; offen sind ausschließlich die konkreten
**Tuning-Zahlen** (Stations-/Aura-/Buff-/Transfer-Werte). Diese werden bei der Umsetzung in `EconomyBalance`
**eingebaut** und durch `balance_sanity_test.dart` abgesichert (V7).

## Umsetzungsphasen

| Phase | Inhalt | Aufwand | Nutzen |
|---|---|---|---|
| 1 | Rang-Schlüssel in `StaffData` + tolerante Migration; Rang als Anzeige (l10n). | klein | mittel (Fundament) |
| 2 | Regelfunktionen (`canAfford`, Level-Gates) in `EconomyBalance`/`EconomyService`. | klein | hoch (V7-Konformität) |
| 3 | Aufstieg `Line Cook → Chef de partie` inkl. Identitätserhalt + UI-Aufrufer. | mittel | hoch |
| 4 | Stationen (Modifikatoren) für Chef de partie. | mittel | mittel (Vielfalt) |
| 5 | Ränge `Sous-chef` und `Chef de cuisine` inkl. **Doppelrolle** (aktiv = Management-Buff auf Attraktivität/Zufriedenheit/Kapazität, formell = Kampf), **Zuteilung**, **Unikat-Invariante** und **Nachrücken**. | mittel | mittel |
| 6 | **Alle** Hilfs-/Service-Rollen als anstellbare Posten (nicht kämpfend), Verwaltung wie Teamärzte. | mittel | mittel |
| 7 | **Wöchentliche Löhne** für alle Ränge (Wochentick, `weeklyMedicCost`-Muster). | klein | mittel (Wirtschaftsschleife) |
| 8 | **Personal Transfer** zwischen eigenen Restaurants (Merge über `toProfileData()`, Kosten, Nachrücken des Chefs). | mittel | mittel |

## Umsetzung: Phase 3 & 4 (erledigt)

**Phase 3 – Aufstieg `Line Cook → Chef de partie`**

- **Neue Klasse:** `lib/objects/player_objects/object_chef_de_partie.dart` (`ObjectChefDePartie extends ObjectApprentice`,
  Stats aus `EconomyBalance.chefDePartieStats`, Rang `kRankChefDePartie`).
- **Generischer Aufstieg:** `ObjectProfile.promoteToRank(character, targetRank)` prüft Ausgangsrang
  (`EconomyService.previousRankOf`), Level-Gate (`canPromote`) und Budget (`canAfford`); `upgradeToLineCook` ist
  jetzt ein dünner Wrapper darauf. `_transferIdentity` überträgt Identität, Persönlichkeit, Ressourcen,
  Match-Historie, Verletzungszustand, Overrides und Station; `_createForRank` erzeugt die Zielklasse,
  `_rankPrefixedName` den Anzeigenamen (`Chef de partie: …`).
- **Persistenz:** `StaffData.type` wird als `rank` geschrieben, `station` mitgeführt; beim Laden erzeugt
  `_staffDataToApprentice` für `chef_de_partie` eine `ObjectChefDePartie`, `_buildApprentice` stellt `station` wieder her.
- **UI:** Rang-Anzeige über den neuen Helfer `l10n/staff_rank.dart` (`rankLabel`) statt `is ObjectLineCook`
  (Detailseite, Personal-Liste, Token-Farbe/-Label im Gefecht). Der Beförderungs-Button in `ScreenRestaurant`
  arbeitet über `EconomyService.nextRank` + `promoteToRank` (Kader-Mitnahme bleibt erhalten).

**Phase 4 – Stationen (Modifikatoren) für `Chef de partie`**

- **Modell/Balance:** `lib/models/stations.dart` (stabile Schlüssel für Basis-Stationen Saucier, Poissonnier,
  Rôtisseur, Entremétier, Garde manger, Pâtissier + Varianten Grillardin, Friturier, Potager, Légumier,
  Charcutier; `StationStat`). In `EconomyBalance`: `StationSpec` (Selbst- und Aura-Prozente),
  `stationSpecs`, `stationBonusMaxPercent` (Deckel), `stationSwitchCost`, `patissierRefillBonusPercent`.
- **Regeln:** `EconomyService.nextRank`/`previousRankOf`, `isStationRank`, `isValidStation`,
  `baseStationOf`, `isSupportStation`, `stationBonusPercent`/`stationAuraPercent` (gedeckelt).
- **Laufzeit/Kampf:** `ObjectApprentice.station` + Selbst-Getter (`stationAttackValue`, `…DefenseValue`,
  `…DamageValue`, `…RangeValue`) und transiente Aura-Felder; `object_player` summiert Persönlichkeit + Station +
  Aura; Reichweitenprüfungen nutzen `stationRangeValue`.
- **Aura:** `lib/services/station_service.dart` (neu) mit `applyStationAuras` – reine, widget-freie Funktion
  (Selbstwirkung über die Getter, Aura auf Verbündete im `stationAuraRadiusByRank`-Radius via
  `HexGrid.distance`); Aufruf zu Rundenbeginn und unmittelbar vor jedem Angriff in `widget_caretaker`.
- **Wahl/Wechsel:** `ObjectProfile.assignStation` (nur ab `chef_de_partie`, Varianten erst nach ihrer Basis,
  erste Wahl kostenfrei, Wechsel kostet `stationSwitchCost`, `canAfford`); UI: Stationszeile + Auswahl-Dialog
  auf der Charakter-Detailseite.
- **Pâtissier:** Support-Station ohne Kampf-Aura; verbessert den Wochen-Refill der übrigen Charaktere
  (`GameClockService._refillStaffResources`).

**Tests:** `test/promote_chef_de_partie_test.dart` (6), `test/station_test.dart` (9) sowie der neue
Sanity-Test „Stations-Bonusse sind definiert und gedeckelt“ in `balance_sanity_test.dart`.

**Weiterhin offen (Phase 5–8):** `ObjectSousChef`/`ObjectHeadChef`, Doppelrolle aktiv/formell,
Unikat-Invariante + Nachrücken, Hilfs-/Service-Rollen, wöchentliche Löhne, Transfer-UI.

## Umsetzung: Phase 5–8 (erledigt)

**Phase 5 – `Sous-chef` & `Chef de cuisine` (Doppelrolle)**

- **Klassen:** `object_sous_chef.dart`, `object_head_chef.dart` (`extends ObjectApprentice`, Stats aus
  `sousChefStats`/`headChefFormalStats`); die Aufstiegsleiter ist damit komplett
  (`apprentice → line_cook → chef_de_partie → sous_chef → head_chef`) – `EconomyService.nextRank`/`previousRankOf`
  und `ObjectProfile._createForRank` bedienen alle Ränge, der Promote-Button nutzt sie automatisch.
- **Doppelrolle:** `ObjectApprentice.headChefRole`/`assignedRestaurantId` (persistiert über `StaffData`).
  Eine Beförderung erzeugt immer einen **formellen** Titelträger; `ObjectProfile.assignHeadChef` teilt zu,
  `activeHeadChef`/`formalHeadChefCandidates` liefern die Lage. **Unikat-Invariante:** pro Restaurant höchstens
  **ein aktiver** Chef – nicht überschreitbar durch Anheuern, Befördern oder Zuteilen. Ein Rückweg
  aktiv → formell ist bewusst **nicht** implementiert (V10 § 6: Reversibilität einseitig).
- **Nachrücken:** `ObjectProfile.nachrueckenHeadChef()` (höchstes Level, bei Gleichstand älteste ID) – automatisch bei
  Tod (Gefecht), Entlassung und Transfer des aktiven Chefs.
- **Management-Profil:** `EconomyBalance.headChefManagementBuffPercent`; ein aktiver Chef hebt Attraktivität,
  Zufriedenheit und Kapazität (`GameClockService.hasActiveHeadChef`). Aktive Chefs sind vom Gefecht ausgeschlossen
  (Checkbox), formelle kämpfen weiter – ihre Stations-Aura wirkt mit Radius 2/3.
- **UI:** Rollen-Anzeige in Personal-Liste und Detailseite, Zuteilungs-Button inkl. Meldung bei belegtem Posten.

**Phase 6 – Hilfs-/Service-Rollen**

- **Modell/Persistenz:** `lib/models/support_role.dart` (`SupportRole`: Communard, Tournant, Aboyeur, Plongeur,
  Commis, Boucher, Garçon) und `SupportRoleData` in `RestaurantData.supportStaff` (`kProfileSchemaVersion = 5`,
  additiv/tolerant – unbekannte Rollen werden beim Laden übersprungen).
- **Verwaltung:** `ObjectProfile.hireSupportRole`/`fireSupportRole`; eigener Abschnitt in `ScreenHireAndFire`
  (Auswahlkarten mit Wirkung + Wochenlohn; angestellte Rollen mit Entlassen), Verwaltung wie Teamärzte.
- **Wirkung:** `lib/services/support_role_service.dart` (reine Auswertung), verdrahtet in der Wirtschaftsschleife:

  | Rolle | Wirkung | Hook |
  |---|---|---|
  | Communard | Refill-Bonus der Kollegen (stapelt mit Pâtissier) | `_refillStaffResources` |
  | Tournant | senkt den Erschöpfungs-Malus der Nulltage | `_probeResources` |
  | Aboyeur | +% passives Einkommen | `catchUp` |
  | Plongeur | senkt den Erweiterungs-Unterhalt | `catchUp` |
  | Commis / Garçon | +Attraktivität / +Zufriedenheit | `attractivenessOf`/`satisfactionOf` |
  | Boucher | +% Beute nach Gefechten | `screen_battle_result` |

**Phase 7 – Wöchentliche Löhne**

- `EconomyBalance.staffWagePerWeekByRank` (100/200/350/600/1000 €) und `supportRoleWagePerWeek`;
  `EconomyService.staffWagePerWeek(rank, thriftiness)` nutzt denselben Thriftiness-Faktor wie die
  Teamarzt-Abrechnung.
- `GameClockService.catchUp` bucht am Blockende `Σ Personal + Σ Hilfsrollen` ab und weist sie als `staffCosts` in
  `WeekSettlement`/`WeeklyTickResult` aus. `ScreenHireAndFire` zeigt die Gesamtwochenlast (Ärzte + Personal +
  Rollen), die Charakter-Detailseite den Wochenlohn.

**Phase 8 – Personal-Transfer (Vervollständigung)**

- **UI:** Aktion **„Verschieben nach …“** in der Personal-Liste: Zielauswahl aus den eigenen, nicht aufgelösten
  Restaurants und Bestätigungsdialog mit den Kosten (das Ziel-Restaurant zahlt).
- **Chef-Sonderfall:** Ein transferierter aktiver Chef wird im Ziel **formell**; in der Quelle rückt sofort ein
  formeller Chef nach. Der Merge im Speichervorgang trägt die Ziel-Liste unverändert mit (`copyWith`).

**Tests:** `test/head_chef_role_test.dart` (12), `test/weekly_wages_test.dart` (5), `test/support_role_test.dart` (12)
und ein neuer Widget-Test in `test/screen_hire_and_fire_test.dart`; `balance_sanity_test.dart` prüft zusätzlich
Lohn-Monotonie, Chef-Buff und die Deckel der Rollen-Effekte. Gesamt **342 Tests grün**, `flutter analyze` ohne
Fehler/Warnungen im neuen Code.

**Bewusste Abweichungen / offen:**

- „Nachrücken in Rücksprache mit dem Spieler“ ist als **deterministische** Auswahl (höchstes Level, dann älteste ID)
  plus UI-Meldung umgesetzt; ein interaktiver Auswahl-Dialog bleibt offen.
- Die Tournant-Erleichterung wirkt dort, wo das Restaurant bekannt ist (Wochen-Proben); der Kampf-Malus bleibt
  unverändert (Durchreichung wäre ein eigener Schritt).
- Der „Neustart des Charakters bei Level 0“ (einzige Rückholmöglichkeit eines aktiven Chefs laut V10 § 6) ist
  nicht implementiert.

## Anhang: Belege

- Referenz: `https://en.wikipedia.org/wiki/Kitchen_brigade` (Abschnitt „Kitchen brigade“); die dortigen
  Einzelnachweise [3]–[7] sind die Grundlage der Verantwortlichkeiten in der Referenztabelle.
- `0-Base.md`: § 3 „Team / Personal“, Entscheidungen und offene Folgepunkte.
- `1_mehrere_Restaurants.md`: `RestaurantData.staff`/`medics` und Merging (`toProfileData()`) – Grundlage des
  Personal-Transfers (V1).
- `2-Wirtschaftsschleife.md`: Anheuer-/Aufstiegskosten, Wirtschaftsschleife.
- `7_Wirtschaftswerte_zentralisieren.md`: V7 – alle Werte in `EconomyBalance`; `lineCookPromotionLevel`,
  `hireApprenticeCost`/`upgradeToLineCookCost`.
- `9_Personal.md`: stabile `StaffData.id`, Persönlichkeit, Ressourcen, Identitätserhalt bei Beförderung.
- Passives Einkommen (die drei gebufften Werte): `team_rules.md` (Abschnitt 2.2, „Einnahmequellen“) und
  `2-Wirtschaftsschleife.md` § 8 – Attraktivität, Kundenzufriedenheit, Kapazität → `GameClockService`
  (`attractivenessOf`/`satisfactionOf`/`capacityOf`), `EconomyBalance.passiveIncomePerCustomerPerWeek`.
- Code: `lib/services/economy_balance.dart` (`startBudget`, `negativeLimit`, `hireApprenticeCost`,
  `upgradeToLineCookCost`, `lineCookPromotionLevel`, `apprenticeStats`, `lineCookStats`),
  `lib/objects/player_objects/object_apprentice.dart`, `object_line_cook.dart`,
  `lib/objects/object_profile.dart` (`hireApprentice`, `upgradeToLineCook`).

