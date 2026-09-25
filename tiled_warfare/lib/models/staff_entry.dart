import 'package:tiled_warfare/utils/json_utils.dart';

/// Kategorie eines Nicht-Kampf-Personal-Eintrags (Option C, `11a`).
///
/// Die Kategorie ist ein **Datenfeld** (Grundsatz G2), kein Parallel-Enum:
/// Sie unterscheidet, **wie** ein Eintrag ausgewertet wird, während die
/// Anstell-/Abrechnungs-Mechanik (G1) für alle Kategorien identisch ist.
enum RoleKind {
  /// Teamarzt (eigenständiges Objekt `ObjectTeamMedic`; teilt nur den Contract).
  medic,

  /// Küchen-Hilfs-/Service-Rolle (bisher `SupportRole`).
  support,

  /// Verwaltung & Marketing (neu, z. B. Social Media Manager).
  management,
}

/// Bildet einen persistierten Kategorie-Namen ab (unbekannt → [RoleKind.support]).
///
/// Tolerante Deserialisierung (V6): Ein unbekannter oder fehlender Wert lässt
/// den Eintrag als Küchen-Rolle gelten – das entspricht den Beständen vor der
/// Einführung des Feldes.
RoleKind roleKindFromName(String? name) {
  for (final value in RoleKind.values) {
    if (value.name == name) return value;
  }
  return RoleKind.support;
}

/// Generalisierter Eintrag für angestelltes **Nicht-Kampf-Personal** (Option C).
///
/// Vereinheitlicht die bisherige `SupportRoleData` um das Feld [kind]: Katalog-/
/// Karten-Anstellung, `id`/[name], Wochenlohn ([costPerWeek]) und
/// Abbuchung im Catch-up sind für alle Kategorien gleich (G1); die Wirkung
/// bleibt kategoriespezifisch (G3).
class StaffEntryData {
  /// Stabile ID (CRC32 aus Name + Anstellungszeitpunkt).
  final int id;

  /// Anzeigename der angestellten Person.
  final String name;

  /// Kategorie (Bestimmungsort der Auswertung, G2).
  final RoleKind kind;

  /// Rollen-Schlüssel innerhalb der Kategorie (`SupportRole.name`,
  /// `ManagementRole.name`, …); unbekannte Werte werden beim Laden übersprungen.
  final String role;

  /// Wöchentlicher Lohn in Euro.
  final int costPerWeek;

  /// Zeitpunkt der Anstellung (optional, für Sortierung/Anzeige).
  final DateTime? hiredAt;

  /// Name des **aktiven Features** (`ManagementFeature.name`) – `null`, wenn
  /// keines läuft (Option C, `11a`; Features sind aktiv und zeitlich befristet).
  String? activeFeature;

  /// Charakter-ID des Kampagnen-Ziels (nur während eines aktiven Features).
  int? featureTargetId;

  /// Startzeitpunkt des aktiven Features (Anker des Fensters).
  DateTime? featureActivatedAt;

  StaffEntryData({
    required this.id,
    required this.name,
    required this.kind,
    required this.role,
    required this.costPerWeek,
    this.hiredAt,
    this.activeFeature,
    this.featureTargetId,
    this.featureActivatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'role': role,
        'costPerWeek': costPerWeek,
        if (hiredAt != null) 'hiredAt': hiredAt!.toIso8601String(),
        if (activeFeature != null) 'activeFeature': activeFeature,
        if (featureTargetId != null) 'featureTargetId': featureTargetId,
        if (featureActivatedAt != null)
          'featureActivatedAt': featureActivatedAt!.toIso8601String(),
      };

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory StaffEntryData.fromJson(Map<String, dynamic> json) => StaffEntryData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        kind: roleKindFromName(readString(json['kind'])),
        role: readString(json['role']) ?? '',
        costPerWeek: readInt(json['costPerWeek']) ?? 0,
        hiredAt: readDateTime(json['hiredAt']),
        activeFeature: readString(json['activeFeature']),
        featureTargetId: readInt(json['featureTargetId']),
        featureActivatedAt: readDateTime(json['featureActivatedAt']),
      );
}
