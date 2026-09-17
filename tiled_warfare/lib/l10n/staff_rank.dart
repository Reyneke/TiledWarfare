import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';

/// Übersetzt einen Karriere-Rang-Schlüssel (`kRank*`) in den lokalisierten
/// Anzeigenamen (Karrierepfade, V10).
///
/// Unbekannte Schlüssel fallen defensiv auf `rankApprentice` zurück – die
/// Anzeige darf nie am Zustand scheitern.
String rankLabel(AppLocalizations l10n, String rank) => switch (rank) {
      kRankLineCook => l10n.rankLineCook,
      kRankChefDePartie => l10n.rankChefDePartie,
      kRankSousChef => l10n.rankSousChef,
      kRankHeadChef => l10n.rankHeadChef,
      _ => l10n.rankApprentice,
    };

/// Übersetzt einen Stations-Schlüssel (`kStation*`) in den lokalisierten
/// Anzeigenamen; `null`/unbekannt → `null` (die UI blendet die Zeile aus).
String? stationLabel(AppLocalizations l10n, String? station) =>
    switch (station) {
      kStationSaucier => l10n.stationSaucier,
      kStationPoissonnier => l10n.stationPoissonnier,
      kStationRotisseur => l10n.stationRotisseur,
      kStationGrillardin => l10n.stationGrillardin,
      kStationFriturier => l10n.stationFriturier,
      kStationEntremetier => l10n.stationEntremetier,
      kStationPotager => l10n.stationPotager,
      kStationLegumier => l10n.stationLegumier,
      kStationGardeManger => l10n.stationGardeManger,
      kStationCharcutier => l10n.stationCharcutier,
      kStationPatissier => l10n.stationPatissier,
      _ => null,
    };
