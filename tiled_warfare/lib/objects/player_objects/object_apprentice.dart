import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/objects/object_token.dart';

/// Status eines Charakters ausserhalb des Gefechts.
///
/// Siehe `doc/rules/team_rules.md` Abschnitt 4.1 für detaillierte
/// Beschreibung der einzelnen Status und ihrer Auswirkungen.
enum CharacterStatus {
  ready(0),
  reeling(1),
  hurt(2),
  afraid(3),
  injured(4),
  dying(5),
  dead(6),
  overkilled(7);

  /// Schweregrad des Status (je höher, desto schwerer verletzt).
  final int severity;
  const CharacterStatus(this.severity);
}

/// Repräsentiert einen angestellten Charakter (Lehrling) im Restaurant-Team.
///
/// Ein Lehrling ist die Einstiegsklasse (siehe `doc/rules/team_rules.md`,
/// Abschnitt 2.3). Er kann durch das Sammeln von Erfahrungspunkten (XP)
/// im Kampf aufsteigen und ab Level 5 zu einem [ObjectLineCook] fortgebildet
/// werden.
///
/// Level-System (gemäß team_rules.md Abschnitt 3.1):
/// - Levelaufstieg erfolgt, sobald currentXPValue ≥ levelValue × 1000
/// - Bei Überschreiten der Schwelle um mehr als das 1.000-Fache werden
///   mehrere Level auf einmal erreicht (überschüssige XP bleiben erhalten).
class ObjectApprentice extends ObjectToken {
  /// Aktuelles Level (beginnt bei 1).
  int levelValue = 1;

  /// Aktuelle Erfahrungspunkte (noch nicht für Levelaufstieg verbraucht).
  int currentXPValue = 0;

  /// Aktueller Verletzungs-Status (ready = gesund).
  CharacterStatus status = CharacterStatus.ready;

  /// Beginn der aktuellen Verletzung (V3) – Anker der Echtzeit-Heilung.
  DateTime? injuryStartedAt;

  /// Status zu Beginn der aktuellen Verletzung (V3) – Basis der idempotenten
  /// Neuberechnung des Heilungsfortschritts.
  CharacterStatus? injuryStartStatus;

  /// Zeitpunkt der automatisch verabreichten Notfall-Spritze (V3).
  /// Solange gesetzt und jünger als `EconomyBalance.emergencyShotDuration`,
  /// ist [suppressedStatus] unterdrückt.
  DateTime? emergencyShotAt;

  /// Der von der Notfall-Spritze unterdrückte Status (V3).
  CharacterStatus? suppressedStatus;

  /// Match-Historie dieses Charakters.
  List<MatchRecord> matchHistory = [];

  /// Erzeugt einen Lehrling.
  ///
  /// [nameZone] wird für die Namenserzeugung genutzt; alternativ kann über
  /// [cuisine] die Küche des Restaurants übergeben werden (§ 9). Ist [nameZone]
  /// nicht gesetzt, wird die Zone der [cuisine] verwendet (Fallback:
  /// [Zone.italy] für Alt-Spielstände).
  ///
  /// [imagePath] fällt auf die Küchen-Token-Grafik ([Cuisine.tokenImagePath])
  /// bzw. auf die generische `token_cook_basic.png` zurück, wenn keine Küche
  /// angegeben ist.
  ObjectApprentice({
    String? name,
    String? imagePath,
    Zone? nameZone,
    Cuisine? cuisine,
    super.attackValue = 40,
    super.defenseValue = 20,
    super.movementValue = 6,
    super.damageValue = 2,
    super.rangeValue = 3,
    super.moneyValue = 100,
    super.xpValue = 25,
  }) : super(
    name: name ??
        "Apprentice: ${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).name()}",
    imagePath: imagePath ??
        cuisine?.tokenImagePath ??
        "assets/images/token/token_cook_basic.png",
  );

  /// Fügt [xp] Erfahrungspunkte hinzu und führt ggf. Levelaufstiege durch.
  ///
  /// Gemäß team_rules.md Abschnitt 3.1:
  /// Ein Levelaufstieg erfolgt, sobald `currentXPValue ≥ levelValue × 1000`.
  /// Werden mehrere Schwellen auf einmal überschritten (z. B. 2.500 XP
  /// bei Level 1), steigt der Charakter entsprechend oft auf.
  ///
  /// Gibt `true` zurück, wenn ein oder mehrere Levelaufstiege stattfanden.
  bool earnXP(int xp) {
    currentXPValue += xp;
    bool leveledUp = false;
    // Nach jedem Levelaufstieg wird die neue Schwelle berechnet, damit
    // überschüssige XP korrekt auf die Folgelevel angerechnet werden.
    while (currentXPValue >= levelValue * 1000) {
      currentXPValue -= levelValue * 1000;
      levelValue++;
      leveledUp = true;
    }
    return leveledUp;
  }
}