import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/l10n/staff_rank.dart';
import 'package:tiled_warfare/l10n/management_feature_labels.dart';
import 'package:tiled_warfare/l10n/management_feature_status.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/screens/screen_character_detail.dart';
import 'package:tiled_warfare/screens/screen_hire_and_fire.dart';
import 'package:tiled_warfare/screens/screen_main.dart';
import 'package:tiled_warfare/services/map_registry.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
import 'package:tiled_warfare/services/profile_storage.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';

class ScreenRestaurant extends StatefulWidget {
  const ScreenRestaurant({super.key});

  @override
  State<ScreenRestaurant> createState() => _ScreenRestaurantState();
}

class _ScreenRestaurantState extends State<ScreenRestaurant>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ObjectProfile _profile = ObjectProfile();

  final Set<ObjectApprentice> _battleReadyCharacters = {};
  List<MapMeta> _mapEntries = [];
  bool _isLoadingMaps = true;
  String? _mapLoadingError;
  int? _selectedMapIndex;
  bool _bankruptcyHandled = false;

  /// Reentranz-Schutz für das Best-effort-Speichern beim Hintergrundwechsel.
  bool _isSaving = false;
  late final TabController _tabController;

  /// Takt des periodischen Nachrechnens bei offenem Screen (L1/§ 6).
  static const Duration _tickInterval = Duration(seconds: 60);

  /// Periodischer Tick für fällige Tage/Wochen bei offenem Screen (L1/§ 6).
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _discoverMaps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBankruptcy();
      _showPendingCatchUp();
    });
    // L1/§ 6: Auch bei sichtbar laufender App fällige Tage/Wochen nachrechnen
    // und die Countdowns aktualisieren.
    _tickTimer = Timer.periodic(_tickInterval, (_) => _runTick());
  }

  /// Zeigt bei Bankrott den Permadeath-Dialog und startet danach einen neuen
  /// Spielstand (V2-Flow: Investoren lösen das Restaurant auf).
  Future<void> _checkBankruptcy() async {
    if (!mounted || _bankruptcyHandled || !_profile.isBankrupt) return;
    _bankruptcyHandled = true;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bankruptDialogTitle),
        content: Text(l10n.bankruptDialogMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.bankruptNewRestaurant),
          ),
        ],
      ),
    );
    _profile.reset();
    await _saveState();
    if (!mounted) return;
    setState(() {
      _battleReadyCharacters.clear();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _runResumeCatchUp();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveOnBackground();
    }
  }

  /// Best-effort-Speichern beim Wechsel in den Hintergrund (V6/L7).
  ///
  /// Ohne Reentranz-Schutz würde ein weiterer Lifecycle-Übergang parallel
  /// schreiben; Fehler werden im Storage geloggt.
  Future<void> _saveOnBackground() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _profile.saveToStorage();
    } finally {
      _isSaving = false;
    }
  }

  /// Schreibt das Write-ahead-Journal vor einer Catch-up-Mutation (P6/`8` P3).
  ///
  /// Ohne fälligen vollen Tag verändert der Tick nichts (die Heilung ist aus
  /// `injuryStartedAt` ableitbar und damit wiederholbar) – dann entfällt das
  /// Journal. Nach erfolgreichem Save räumt der Aufrufer es über
  /// [ProfileStorage.clearTickJournal] wieder weg.
  Future<void> _beginTickJournal(DateTime now) async {
    final lastSeenAt = _profile.lastSeenAt;
    if (lastSeenAt == null ||
        GameClockService.daysElapsed(lastSeenAt, now) <= 0) {
      return;
    }
    await ProfileStorage.writeTickJournal(
      _profile.id,
      restaurantId: _profile.activeRestaurantId,
      lastSeenAt: lastSeenAt,
      weekAnchorAt: _profile.weekAnchorAt,
    );
  }

  /// Holt beim Wiederaufnehmen der App fällige Wochen nach (V8) **und** die
  /// Echtzeit-Heilung/den Spritzen-Rückfall (V3); aktualisiert die Ansicht
  /// (inkl. Bankrott-Prüfung) und zeigt die Buchungen an (L2/§ 6).
  Future<void> _runResumeCatchUp() async {
    if (!mounted) return;
    // P6: Write-ahead vor der Mutation – ein Abbruch dazwischen bleibt so
    // erkennbar (die Buchungen selbst holt der nächste Tick idempotent nach).
    final now = DateTime.now();
    await _beginTickJournal(now);
    // V3: Heilung läuft auch ohne fällige Woche weiter, daher immer speichern.
    final result = _profile.runCatchUp(now);
    final saved = await _saveState();
    if (saved) await ProfileStorage.clearTickJournal(_profile.id);
    if (!mounted) return;
    setState(() {});
    _showCatchUpResult(result);
    _checkBankruptcy();
  }

  /// Periodischer Tick (L1/§ 6): rechnet fällige Tage/Wochen nach, während die
  /// App sichtbar offen ist, und aktualisiert die Countdowns.
  ///
  /// Gespeichert wird nur, wenn tatsächlich ein Tag/Block abgerechnet wurde
  /// (Reentranz-Schutz über [_isSaving], vgl. [_saveOnBackground]).
  Future<void> _runTick() async {
    if (!mounted || _isSaving) return;
    final now = DateTime.now();
    await _beginTickJournal(now);
    final result = _profile.runCatchUp(now);
    final changed = result.weeks > 0 || result.leftoverDays > 0;
    if (changed) {
      final saved = await _saveState();
      if (saved) await ProfileStorage.clearTickJournal(_profile.id);
      if (!mounted) return;
      _showCatchUpResult(result);
    } else {
      // Ohne Mutation ist das Journal erledigt (der Save kommt aus anderen
      // Anlässen; ein übrig gebliebenes Journal wäre hier irreführend).
      await ProfileStorage.clearTickJournal(_profile.id);
    }
    if (!mounted) return;
    setState(() {});
    if (result.bankrupt) _checkBankruptcy();
  }

  /// Zeigt ein beim Login vorbereitetes Catch-up-Ergebnis einmalig an (L2).
  void _showPendingCatchUp() {
    final pending = _profile.pendingCatchUpResult;
    if (pending == null) return;
    _profile.pendingCatchUpResult = null;
    if (!mounted) return;
    _showCatchUpResult(pending);
  }

  /// Zeigt die fälligen Buchungen eines Catch-up als SnackBar (L2/§ 6).
  ///
  /// Volle abgerechnete Blöcke öffnen den **Wochenbericht** als Dialog (inkl.
  /// Stadtteil-Rangliste, Kapitel 12/13); reine Resttage bleiben eine SnackBar.
  void _showCatchUpResult(WeeklyTickResult result) {
    if (result.weeks <= 0 && result.leftoverDays <= 0) return;
    final l10n = AppLocalizations.of(context)!;
    if (result.weeks > 0) {
      _showWeekReport(result);
      return;
    }
    final parts = <String>[];
    if (result.leftoverDays > 0 && result.leftoverIncome > 0) {
      parts.add(
          l10n.catchUpLeftover(result.leftoverDays, result.leftoverIncome));
    }
    // V13: durch unentdeckte Rivalen-Sabotage abgeschöpftes Einkommen (der
    // Betrag ist in `passiveIncome` bereits abgezogen – hier nur transparent).
    if (result.rivalSabotageLosses > 0) {
      parts.add(l10n.catchUpRivalSabotageLoss(result.rivalSabotageLosses));
    }
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(parts.join('\n'))));
  }

  /// Wochenbericht (Kapitel 12/13): Buchungen des Blocks plus Rangliste.
  ///
  /// Die 4.1/4-Entscheidung „Platzierung als Liste im Wochenbericht, ‚Platz X
  /// von Y‘ im Restaurant-Screen“ wird hier umgesetzt.
  Future<void> _showWeekReport(WeeklyTickResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final standings = result.standings;
    final lines = <String>[
      l10n.catchUpSummary(
        result.weeks,
        result.passiveIncome - result.leftoverIncome,
        result.medicCosts,
        result.upgradeUpkeep,
        result.negativeInterest,
      ),
    ];
    if (result.leftoverDays > 0 && result.leftoverIncome > 0) {
      lines.add(
          l10n.catchUpLeftover(result.leftoverDays, result.leftoverIncome));
    }
    if (result.rivalSabotageLosses > 0) {
      lines.add(l10n.catchUpRivalSabotageLoss(result.rivalSabotageLosses));
    }
    // Kapitel 14/Q7b: Die FRT greift Rivalen offen an – sichtbar macht das die
    // gesunkenen PP der Rivalen in der Rangliste unten.
    if (result.frtRivalAttacks > 0) {
      lines.add(l10n.catchUpFrtRivalAttacks(result.frtRivalAttacks));
    }
    // `11a` P4: Einmalkosten der im Block aktivierten Features – sie sind bei
    // der Aktivierung bereits abgebucht und werden hier transparent ausgewiesen.
    if (result.prepaidFeatureCosts > 0) {
      lines.add(l10n.catchUpPrepaidFeatureCost(result.prepaidFeatureCosts));
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(l10n.weekReportTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lines.join('\n')),
                if (result.settlements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.weekReportWeeksTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  for (final settlement in result.settlements)
                    _buildWeekBreakdown(theme, l10n, settlement),
                ],
                if (standings != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.rankingSectionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final row in standings.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _standingLabel(l10n, row),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: row.isPlayer ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  /// Ein Block der Wochen-Aufschlüsselung (P6, 4.2/#5).
  ///
  /// Bewusst initial **eingeklappt**: Der Bericht kann bis zu
  /// [EconomyBalance.maxCatchUpWeeks] Blöcke umfassen; der Kopf zeigt deshalb
  /// bereits das Budget nach dem Block, die Details (Einkommen, Ärzte,
  /// Personal, Unterhalt, Zinsen, Strafen, Features, Sabotage) erst beim
  /// Aufklappen.
  Widget _buildWeekBreakdown(
    ThemeData theme,
    AppLocalizations l10n,
    WeekSettlement settlement,
  ) {
    final rows = <String>[
      l10n.weekReportLineIncome(settlement.income),
      if (settlement.medicCosts != 0)
        l10n.weekReportLineMedics(settlement.medicCosts),
      if (settlement.staffCosts != 0)
        l10n.weekReportLineStaff(settlement.staffCosts),
      if (settlement.upgradeUpkeep != 0)
        l10n.weekReportLineUpkeep(settlement.upgradeUpkeep),
      if (settlement.negativeInterest != 0)
        l10n.weekReportLineInterest(settlement.negativeInterest),
      if (settlement.penaltyCosts != 0)
        l10n.weekReportLinePenalties(settlement.penaltyCosts),
      if (settlement.featureCosts != 0)
        l10n.weekReportLineFeatures(settlement.featureCosts),
      if (settlement.prepaidFeatureCosts != 0)
        l10n.weekReportLinePrepaidFeatures(settlement.prepaidFeatureCosts),
      if (settlement.rivalSabotageLoss != 0)
        l10n.weekReportLineSabotage(settlement.rivalSabotageLoss),
      l10n.weekReportLineBudgetAfter(settlement.budgetAfter),
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
      title: Text(
        l10n.weekReportWeekHeader(
          settlement.weekIndex + 1,
          _formatReportDate(settlement.periodStart),
          _formatReportDate(settlement.periodEnd),
        ),
        style: theme.textTheme.bodyMedium,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            rows.join('\n'),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Datum im Bericht – bewusst ohne `DateFormat`, weil dafür die
  /// intl-Locale-Daten initialisiert sein müssten (Konvention wie
  /// `screen_character_detail.dart`).
  String _formatReportDate(DateTime date) =>
      '${date.day}.${date.month}.${date.year}';

  /// Eine Zeile der Rangliste: „1. Name — PP 63 (Verbündet) · Sie“.
  String _standingLabel(AppLocalizations l10n, RivalStanding row) {
    final buffer = StringBuffer(
      '${row.rank}. ${row.name} — PP ${row.powerProjection}',
    );
    final stance = row.stance;
    if (stance != null) buffer.write(' (${_stanceLabel(l10n, stance)})');
    if (row.insolvent) buffer.write(' · ${l10n.rivalInsolvent}');
    if (row.isPlayer) buffer.write(' · ${l10n.rankingYou}');
    return buffer.toString();
  }

  /// l10n-Label der Rivalen-Stance (Kapitel 13, Q9).
  String _stanceLabel(AppLocalizations l10n, RivalStance stance) =>
      switch (stance) {
        RivalStance.ally => l10n.stanceAlly,
        RivalStance.neutral => l10n.stanceNeutral,
        RivalStance.enemy => l10n.stanceEnemy,
      };

  void _onThemeChanged() {
    setState(() {});
  }

  /// Lädt die Karten-Konfiguration aus assets/maps/maps.json via [MapRegistry].
  Future<void> _discoverMaps() async {
    try {
      final registry = await MapRegistry.loadFromAsset();
      if (!mounted) return;
      setState(() {
        _mapEntries = registry.maps;
        _isLoadingMaps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mapLoadingError = e.toString();
        _isLoadingMaps = false;
      });
    }
  }

  void _toggleTheme() {
    final currentThemeMode = AppTheme.themeModeNotifier.value;
    final ThemeMode next;
    switch (currentThemeMode) {
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.system;
      case ThemeMode.system:
        next = ThemeMode.light;
    }
    AppTheme.themeModeNotifier.value = next;
  }

  /// Speichert den aktiven Spielstand und meldet Fehlschläge sichtbar (V6/L4).
  Future<bool> _saveState() async {
    final ok = await _profile.saveToStorage();
    if (!ok && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveFailed)),
      );
    }
    return ok;
  }

  /// Switches to another savegame of the profile.
  ///
  /// Saves the current state first, then reloads [restaurantId] from storage
  /// and resets the local UI states (battle selection, derived logo image).
  Future<void> _switchRestaurant(int restaurantId) async {
    if (restaurantId == _profile.activeRestaurantId) return;
    await _saveState();

    final loadResult = await ProfileStorage.loadAllProfiles();
    final data = loadResult.profiles.cast<ProfileData?>().firstWhere(
          (p) => p!.id == _profile.id,
          orElse: () => null,
        );
    if (data == null) return;

    // Echtzeit-Catch-up (V8) für den gewechselten Spielstand.
    final target = data.restaurants.cast<RestaurantData?>().firstWhere(
          (r) => r!.id == restaurantId,
          orElse: () => null,
        );
    WeeklyTickResult? catchUp;
    if (target != null) {
      // P6: Write-ahead-Journal für den gewechselten Spielstand (Anker vor dem
      // Tick); aufgeräumt wird es nur nach erfolgreichem Save.
      final before = target.lastSeenAt;
      final now = DateTime.now();
      if (before != null && GameClockService.daysElapsed(before, now) > 0) {
        await ProfileStorage.writeTickJournal(
          data.id,
          restaurantId: target.id,
          lastSeenAt: before,
          weekAnchorAt: target.weekAnchorAt,
        );
      }
      catchUp = GameClockService.catchUp(target, now);
      final saved = await ProfileStorage.saveProfile(data);
      if (saved) await ProfileStorage.clearTickJournal(data.id);
    }

    _profile.loadFromData(data, restaurantId: restaurantId);
    setState(() {
      _battleReadyCharacters.clear();
      _tabController.index = 0;
    });
    if (catchUp != null) _showCatchUpResult(catchUp);
  }

  /// Shows a dialog to switch to another (non-dissolved) savegame.
  Future<void> _showSwitchRestaurantDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final restaurants = _profile.profileRestaurants
        .where((r) => r.id != _profile.activeRestaurantId)
        .toList();

    if (restaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noOtherSavegames)),
      );
      return;
    }

    final selectedId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.switchRestaurant),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in restaurants)
                ListTile(
                  enabled: !r.isDissolved,
                  leading: CircleAvatar(
                    child: r.isDissolved
                        ? const Icon(Icons.broken_image)
                        : const Icon(Icons.restaurant),
                  ),
                  title: Text(r.name),
                  subtitle: Text(
                    r.isDissolved
                        ? l10n.dissolved
                        : l10n.districtLabel(r.district ?? ''),
                  ),
                  onTap: () => Navigator.pop(dialogContext, r.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (selectedId != null) {
      await _switchRestaurant(selectedId);
    }
  }

  Future<void> _showEditRestaurantNameDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _profile.restaurantName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameRestaurant),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.restaurantName,
            hintText: l10n.newNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _profile.restaurantName = newName;
      });
      await _saveState();
    }
  }

  Future<void> _goToBattle() async {
    _profile.selectTeamForBattle(_battleReadyCharacters.toList());
    final selectedEntry = _selectedMapIndex != null
        ? _mapEntries[_selectedMapIndex!]
        : _mapEntries.first;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenMain(
          mapPath: selectedEntry.tmxPath,
          // Kapitel 14 (FRT): Die Monsterstärke folgt der Korruption des
          // Stadtteils zum Gefechtsbeginn (Q3).
          monsterStrengthFactor:
              FrtService.monsterStrengthFactor(_profile.corruptionPercent),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        // P6: Spielstände (und damit Logos) liegen im aufgelösten
        // Basisverzeichnis – nicht mehr zwingend relativ zu `profiles/`.
        await ProfileStorage.ensureInitialized();
        final profileDir =
            Directory('${ProfileStorage.baseDirName}/${_profile.id}');
        if (!await profileDir.exists()) {
          await profileDir.create(recursive: true);
        }

        final imageExtension = image.name.contains('.')
            ? '.${image.name.split('.').last}'
            : '.png';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        // Neue Bilder werden **absolut** gespeichert (P6), damit sie auch nach
        // einem Wechsel des Speicherorts gefunden werden.
        final destPath = File(
          '${profileDir.path}/restaurant_$timestamp$imageExtension',
        ).absolute.path;
        final destFile = File(destPath);

        // Alte Logos erst NACH erfolgreichem Schreiben entfernen (V4/P6): die
        // Liste wird vor dem Schreiben erfasst und enthält die neue Datei
        // daher noch nicht. Schlägt das Schreiben fehl, bleibt das alte Logo.
        final oldLogos = await profileDir
            .list()
            .where((entity) =>
                entity is File && entity.path.contains('restaurant_'))
            .toList();

        await destFile.writeAsBytes(await image.readAsBytes());

        for (final old in oldLogos) {
          await (old as File).delete();
        }

        setState(() {
          _profile.restaurantLogoPath = destPath;
        });
        await _saveState();
      } catch (e) {
        debugPrint('Image pick error: $e');
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restaurantLogoError)),
        );
      }
    }
  }

  Widget _buildMapTile(int index, MapMeta mapEntry, ThemeData theme) {
    final isSelected = _selectedMapIndex == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMapIndex = isSelected ? null : index;
          });
        },
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: mapEntry.previewPath != null
                        ? Image.asset(
                            mapEntry.previewPath!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(theme),
                          )
                        : _buildPlaceholder(theme),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    mapEntry.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.chevron_right,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.map,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Erzeugt ein einheitliches Fehler-Widget für defekte Bilder.
  Widget _buildImageErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      height: 200,
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image, size: 64),
    );
  }

  /// Gibt eine Farbe basierend auf dem Verletzungsstatus zurück.
  /// Stellt 5 visuelle Stufen dar (statt vorher nur 3), damit der Spieler
  /// ohne Detailansicht den Gesundheitszustand erkennen kann.
  Color _statusAvatarColor(CharacterStatus status) {
    switch (status) {
      case CharacterStatus.ready:
        return Colors.green;
      case CharacterStatus.reeling:
        return Colors.lightGreenAccent;
      case CharacterStatus.hurt:
        return Colors.orange;
      case CharacterStatus.afraid:
      case CharacterStatus.injured:
        return Colors.deepOrange;
      case CharacterStatus.dying:
        return Colors.red;
      case CharacterStatus.dead:
      case CharacterStatus.overkilled:
        return Colors.grey;
    }
  }

  /// Gibt den lokalisierten Text für einen [CharacterStatus] zurück.
  String _statusText(AppLocalizations l10n, CharacterStatus status) {
    switch (status) {
      case CharacterStatus.ready:
        return l10n.statusReady;
      case CharacterStatus.reeling:
        return l10n.statusReeling;
      case CharacterStatus.hurt:
        return l10n.statusHurt;
      case CharacterStatus.afraid:
        return l10n.statusAfraid;
      case CharacterStatus.injured:
        return l10n.statusInjured;
      case CharacterStatus.dying:
        return l10n.statusDying;
      case CharacterStatus.dead:
        return l10n.statusDead;
      case CharacterStatus.overkilled:
        return l10n.statusOverkilled;
    }
  }

  /// Baut die sortierte Personal-Liste auf.
  /// Sortierung: Schwerstverletzte zuerst (höchster [CharacterStatus.severity]).
  Widget _buildSortedPersonnelList(ThemeData theme, AppLocalizations l10n) {
    final sortedPersonal = List<ObjectApprentice>.from(_profile.personal)
      ..sort((a, b) => b.status.severity.compareTo(a.status.severity));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPersonal.length,
      itemBuilder: (context, index) {
        final character = sortedPersonal[index];
        final isReady = _battleReadyCharacters.contains(character);
        // V10 § 6: Der **aktive** Chef de cuisine hat ein Management-Profil und
        // zieht nicht ins Gefecht; formelle Chefs kämpfen weiter.
        final bool canFight = character.status != CharacterStatus.dying &&
            character.headChefRole != kHeadChefRoleActive;
        final hasMedic = _profile.hiredMedics.isNotEmpty;
        final needsTreat = character.status != CharacterStatus.ready;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreenCharacterDetail(
                      character: character),
                ),
              );
              setState(() {});
            },
            leading: CircleAvatar(
              backgroundColor: _statusAvatarColor(character.status),
              // Küchen-Token als Personal-Grafik (§ 9); Icon als Fallback,
              // falls ein Alt-Spielstand keinen gültigen Pfad hat.
              child: ClipOval(
                child: Image.asset(
                  character.imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    _rankIcon(character),
                    color: character.status == CharacterStatus.dying
                        ? Colors.white
                        : null,
                  ),
                ),
              ),
            ),
            title: Text(
              '${character.name} (${l10n.level(character.levelValue)})',
            ),
            subtitle: Text(
              [
                '❤️ ${GameClockService.woundValueFor(character.status)}',
                _statusText(l10n, character.status),
                if (character.status != CharacterStatus.ready)
                  _healingInfoText(character, l10n),
                '⚔️ ${character.attackValue}',
                '🛡️ ${character.defenseValue}',
                '🏃 ${character.movementValue}',
                if (character.rank != kRankApprentice)
                  '🎯 ${character.stationRangeValue}',
                if (stationLabel(l10n, character.station) != null)
                  stationLabel(l10n, character.station)!,
                if (character.rank == kRankHeadChef)
                  character.headChefRole == kHeadChefRoleActive
                      ? l10n.headChefRoleActive
                      : l10n.headChefRoleFormal,
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMedic && needsTreat)
                  IconButton(
                    icon: const Icon(Icons.healing,
                        color: Colors.green),
                    tooltip: l10n.medicAssignTooltip,
                    onPressed: () async {
                      final medic =
                          _profile.hiredMedics.first;
                      if (medic.treatCharacter(character)) {
                        setState(() {});
                        await _saveState();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.treatmentSuccess(character.name)),
                            ),
                          );
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.treatmentFailed),
                            ),
                          );
                      }
                    },
                  ),
                  if (_nextRankOf(character) != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward,
                          color: Colors.amber),
                      tooltip: _promoteActionLabel(
                        l10n,
                        _nextRankOf(character)!,
                      ),
                      onPressed: () => _promoteCharacter(character),
                    ),
                  if (character.rank == kRankHeadChef &&
                      character.headChefRole != kHeadChefRoleActive)
                    IconButton(
                      icon: const Icon(Icons.workspace_premium,
                          color: Colors.amber),
                      tooltip: l10n.headChefAssign,
                      onPressed: () => _assignHeadChef(character),
                    ),
                  if (_transferTargets.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.drive_file_move_outline,
                          color: Colors.blueGrey),
                      tooltip: l10n.transferTo,
                      onPressed: () => _transferCharacter(character),
                    ),
                  IconButton(
                    icon: const Icon(Icons.person_remove,
                        color: Colors.red),
                    tooltip: l10n.fire,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.fire),
                          content: Text(
                            l10n.fireConfirm(character.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.fire),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        setState(() {
                          _profile.fireCharacter(character);
                          _battleReadyCharacters.remove(character);
                        });
                        await _saveState();
                      }
                    },
                  ),
                Checkbox(
                  value: isReady,
                  onChanged: canFight
                      ? (value) {
                          setState(() {
                            if (value == true) {
                              _battleReadyCharacters
                                  .add(character);
                            } else {
                              _battleReadyCharacters
                                  .remove(character);
                            }
                          });
                        }
                      : null,
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  /// Führt die Beförderung eines Charakters in den nächsten Rang durch (V5/V10).
  ///
  /// Zeigt Zielrang und Kosten, holt eine Bestätigung ein und überträgt
  /// anschließend die Kader-Auswahl auf den neuen Charakter, damit der Haken
  /// nicht am alten Objekt hängen bleibt. Die Stationswahl folgt ab
  /// `chef_de_partie` auf der Detailseite (V10, Phase 4).
  Future<void> _promoteCharacter(ObjectApprentice character) async {
    final l10n = AppLocalizations.of(context)!;
    final targetRank = _nextRankOf(character);
    if (targetRank == null) return;

    final requiredLevel = EconomyService.promotionLevel(targetRank);
    if (character.levelValue < requiredLevel) {
      final message = targetRank == kRankLineCook
          ? l10n.promoteLevelRequired
          : l10n.promoteLevelRequiredFor(requiredLevel);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // § 10 (`school`): Der angezeigte Preis ist der **tatsächlich gebuchte**
    // (nach Abzug des Schulungsraums) – eine Quelle der Wahrheit, wie bei
    // `upgradePurchaseCost`.
    final cost = _profile.promotionPurchaseCost(targetRank);
    final actionLabel = _promoteActionLabel(l10n, targetRank);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel),
        content: Text(
          targetRank == kRankLineCook
              ? l10n.promoteConfirm(character.name, cost)
              : l10n.promoteConfirmRank(
                  character.name,
                  rankLabel(l10n, targetRank),
                  cost,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final wasInSquad = _battleReadyCharacters.contains(character);
    final promoted = _profile.promoteToRank(character, targetRank);
    if (promoted == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.promoteNotEnoughBudget)),
        );
      return;
    }

    setState(() {
      if (wasInSquad) {
        _battleReadyCharacters
          ..remove(character)
          ..add(promoted);
      }
    });
    await _saveState();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.promoteSuccess(promoted.name))),
      );
  }

  /// Nächster Rang des Charakters (V10) – `null`, wenn die Kette endet.
  String? _nextRankOf(ObjectApprentice character) =>
      EconomyService.nextRank(character.rank);

  /// Beschriftung der Beförderungsaktion für [targetRank] (l10n).
  String _promoteActionLabel(AppLocalizations l10n, String targetRank) =>
      switch (targetRank) {
        kRankChefDePartie => l10n.promoteToChefDePartie,
        kRankSousChef => l10n.promoteToSousChef,
        kRankHeadChef => l10n.promoteToHeadChef,
        _ => l10n.promoteToLineCook,
      };

  /// Mögliche Ziel-Restaurants für einen Personal-Transfer (V10, Phase 8):
  /// eigene, nicht aufgelöste Spielstände außer dem aktiven.
  List<RestaurantData> get _transferTargets => _profile.profileRestaurants
      .where((r) => r.id != _profile.activeRestaurantId && !r.isDissolved)
      .toList();

  /// Verschiebt [character] in ein anderes eigenes Restaurant (V10, Phase 8).
  ///
  /// Das Ziel-Restaurant zahlt die level-/ranggestaffelten Transferkosten; die
  /// Verschiebung wird beim nächsten Speichervorgang im Ziel-Spielstand
  /// wirksam (`ObjectProfile.transferStaff`/`toProfileData`).
  Future<void> _transferCharacter(ObjectApprentice character) async {
    final l10n = AppLocalizations.of(context)!;
    final targets = _transferTargets;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.transferNoTargets)));
      return;
    }

    final target = await showDialog<RestaurantData>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.transferSelectTitle),
        children: [
          for (final restaurant in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, restaurant),
              child: Text('${restaurant.name} · ${restaurant.budget} €'),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    final cost = EconomyService.transferCost(level: character.levelValue);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.transferTo),
        content: Text(
          l10n.transferConfirm(character.name, target.name, cost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.transferTo),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final wasInSquad = _battleReadyCharacters.contains(character);
    final ok = _profile.transferStaff(
      staff: character,
      targetRestaurantId: target.id,
    );
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.transferFailed)));
      return;
    }

    setState(() {
      if (wasInSquad) _battleReadyCharacters.remove(character);
    });
    await _saveState();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.transferSuccess(character.name, target.name)),
        ),
      );
  }

  /// Teilt einen formellen Chef de cuisine dem Restaurant als **aktiven** Chef
  /// zu (V10 § 6); die Unikat-Invariante prüft [ObjectProfile.assignHeadChef].
  Future<void> _assignHeadChef(ObjectApprentice character) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_profile.assignHeadChef(character)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.headChefAssignForbidden)),
        );
      return;
    }
    setState(() {});
    await _saveState();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.headChefAssigned(character.name))),
      );
  }

  /// Rangabhängiges Symbol für die Personal-Liste (V10).
  IconData _rankIcon(ObjectApprentice character) =>
      switch (character.rank) {
        kRankChefDePartie => Icons.restaurant_menu,
        kRankLineCook => Icons.restaurant,
        _ => Icons.school,
      };

  /// Kompakter Heil-/Rückfall-Countdown für die Personal-Liste (V3).
  String _healingInfoText(ObjectApprentice character, AppLocalizations l10n) {
    final now = DateTime.now();
    if (character.emergencyShotAt != null) {
      final remaining =
          GameClockService.remainingShotTime(character.emergencyShotAt, now);
      return l10n.shotCountdown(remaining.inHours, remaining.inMinutes % 60);
    }
    if (character.status == CharacterStatus.ready) {
      return l10n.healingComplete;
    }
    final perStage = GameClockService.healTimePerStageFor(
      quality: GameClockService.bestHiredQuality(_profile.hiredMedics),
      upgrades: _profile.activeUpgrades,
    );
    final remaining = GameClockService.remainingHealingTime(
      status: character.status,
      injuryStartedAt: character.injuryStartedAt,
      perStage: perStage,
      now: now,
    );
    return l10n.healCountdown(remaining.inHours, remaining.inMinutes % 60);
  }

  /// Übersetzt eine [Cuisine] in den lokalisierten Anzeigenamen.
  String _cuisineName(AppLocalizations l10n, Cuisine cuisine) {
    switch (cuisine) {
      case Cuisine.italian:
        return l10n.cuisineItalian;
      case Cuisine.japanese:
        return l10n.cuisineJapanese;
      case Cuisine.chinese:
        return l10n.cuisineChinese;
      case Cuisine.german:
        return l10n.cuisineGerman;
      case Cuisine.canadian:
        return l10n.cuisineCanadian;
      case Cuisine.mexican:
        return l10n.cuisineMexican;
    }
  }

  /// Zeigt die aktuelle Küche, einen aktiven Rebranding-Malus und bietet den
  /// (bezahlten) Küchenwechsel an.
  Widget _buildCuisineRow(ThemeData theme, AppLocalizations l10n) {
    final now = DateTime.now();
    final penaltyUntil = _profile.rebrandingPenaltyUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cuisineLabel(_cuisineName(l10n, _profile.activeCuisine)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (penaltyUntil != null && now.isBefore(penaltyUntil))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.rebrandingPenaltyActive(
                (penaltyUntil.difference(now).inHours / 24).ceil(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _rebrandCuisine,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(l10n.rebrandCuisine),
          ),
        ),
      ],
    );
  }

  /// Führt einen Küchenwechsel (Rebranding, § 9) durch: Auswahl → Bestätigung →
  /// Kosten abbuchen → speichern.
  Future<void> _rebrandCuisine() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<Cuisine>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.rebrandDialogTitle),
        children: [
          for (final cuisine in Cuisine.values)
            if (cuisine != _profile.activeCuisine)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, cuisine),
                child: Text(_cuisineName(l10n, cuisine)),
              ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rebrandDialogTitle),
        content: Text(l10n.rebrandDialogMessage(EconomyBalance.rebrandingCost)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.rebrandConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!_profile.rebrandCuisine(picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rebrandNotEnoughBudget)),
      );
      return;
    }
    await _saveState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.rebrandSuccess)),
    );
    setState(() {});
  }

  /// Übersetzt einen [UpgradeType] in den lokalisierten Anzeigenamen.
  String _upgradeName(AppLocalizations l10n, UpgradeType type) {
    switch (type) {
      case UpgradeType.tables:
        return l10n.upgradeTables;
      case UpgradeType.kitchen:
        return l10n.upgradeKitchen;
      case UpgradeType.signage:
        return l10n.upgradeSignage;
      case UpgradeType.decoration:
        return l10n.upgradeDecoration;
      case UpgradeType.jukebox:
        return l10n.upgradeJukebox;
      case UpgradeType.cellar:
        return l10n.upgradeCellar;
      case UpgradeType.coldRoom:
        return l10n.upgradeColdRoom;
      case UpgradeType.firstAid:
        return l10n.upgradeFirstAid;
      case UpgradeType.lounge:
        return l10n.upgradeLounge;
      case UpgradeType.certification:
        return l10n.upgradeCertification;
      case UpgradeType.vault:
        return l10n.upgradeVault;
      case UpgradeType.school:
        return l10n.upgradeSchool;
      case UpgradeType.security:
        return l10n.upgradeSecurity;
      case UpgradeType.stars:
        return l10n.upgradeStars;
    }
  }

  /// Abschnitt mit allen Restauranterweiterungen (§ 10).
  Widget _buildUpgradesSection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(l10n.upgradesSection, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        for (final type in UpgradeType.values)
          _buildUpgradeTile(theme, l10n, type),
      ],
    );
  }

  Widget _buildUpgradeTile(
    ThemeData theme,
    AppLocalizations l10n,
    UpgradeType type,
  ) {
    final spec = EconomyBalance.upgrades[type]!;
    final level = _profile.upgradeLevel(type);
    final maxed = level >= spec.maxLevel;
    final nextCost = maxed ? 0 : _profile.upgradePurchaseCost(type);
    final upkeep = EconomyService.upgradeUpkeepPerWeek(type, level);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _upgradeName(l10n, type),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  l10n.upgradeLevel(level, spec.maxLevel),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              maxed ? l10n.upgradeMaxReached : l10n.upgradeBuyCost(nextCost),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              l10n.upgradeUpkeepCost(upkeep),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: maxed ? null : () => _buyUpgrade(type),
                  child: Text(l10n.upgradeBuy),
                ),
                OutlinedButton(
                  onPressed: level <= 0 ? null : () => _downgradeUpgrade(type),
                  child: Text(l10n.upgradeDowngrade),
                ),
                OutlinedButton(
                  onPressed: level <= 0 ? null : () => _sellUpgrade(type),
                  child: Text(l10n.upgradeSell),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyUpgrade(UpgradeType type) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_profile.buyUpgrade(type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.upgradeNotEnoughBudget)),
      );
      return;
    }
    await _saveState();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _downgradeUpgrade(UpgradeType type) async {
    if (!_profile.downgradeUpgrade(type)) return;
    await _saveState();
    if (!mounted) return;
    setState(() {});
  }

  /// Verkauft [type] vollständig – nach Rückfrage, weil die Erstattung nur
  /// `upgradeSellRefundRate` der investierten Summe beträgt.
  Future<void> _sellUpgrade(UpgradeType type) async {
    final l10n = AppLocalizations.of(context)!;
    final level = _profile.upgradeLevel(type);
    if (level <= 0) return;
    final refund = EconomyService.sellRefund(type, level);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.upgradeSell),
        content: Text(l10n.upgradeSellConfirm(refund)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.upgradeSell),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final booked = _profile.sellUpgrade(type);
    if (booked <= 0) return;
    await _saveState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.upgradeSold(booked))),
    );
    setState(() {});
  }

  /// Zeigt den Countdown bis zur nächsten Wochenabbuchung sowie Kunden/Woche,
  /// passives Einkommen, Arztkosten und eine Warnung nahe der Negativgrenze.
  Widget _buildEconomyInfo(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final snapshot = _profile.activeRestaurantSnapshot();
    final anchor =
        snapshot.weekAnchorAt ?? snapshot.lastSeenAt ?? now;
    final nextTick = GameClockService.nextWeeklyTick(anchor, now);
    final days = nextTick.difference(now).inDays;
    final attractiveness = GameClockService.attractivenessOf(snapshot, now: now);
    final satisfaction = GameClockService.satisfactionOf(snapshot);
    final capacity = GameClockService.capacityOf(snapshot);
    final customers = PassiveIncomeService.customersPerWeek(
      attractiveness: attractiveness,
      satisfaction: satisfaction,
      capacity: capacity,
    );
    final passive = PassiveIncomeService.passiveIncomePerWeek(
      attractiveness: attractiveness,
      satisfaction: satisfaction,
      capacity: capacity,
    );
    final medicCosts = snapshot.medics.fold<int>(
      0,
      (sum, medic) => sum + medic.costPerWeek,
    );
    final nearLimit = _profile.budget <= EconomyBalance.negativeLimit ~/ 2;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(l10n.nextBillingCountdown(days < 0 ? 0 : days), style: style),
        Text(
          '${l10n.customersPerWeekLabel(customers)}  ·  '
          '${l10n.passiveIncomeLabel(passive)}  ·  '
          '${l10n.medicCostsLabel(medicCosts)}',
          style: style,
        ),
        if (nearLimit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.budgetWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        _buildActiveFeaturesInfo(theme, l10n),
      ],
    );
  }

  /// Countdown der **laufenden Features** (`11a` P4, Schritt 2a).
  ///
  /// Die Personal-Karte zeigt den Feature-Status nur im Personal-Screen; hier
  /// steht er **außerhalb der Personal-Karte** direkt unter der Wirtschaftszeile
  /// des Restaurant-Screens. Die Auswertung ist anker-basiert und wird mit dem
  /// Personal-Screen geteilt (`managementFeatureStatusLine`), damit beide
  /// dieselbe Sprache sprechen.
  ///
  /// Bewusst **eine** kompakte Zeile (mit Ellipse): Der Kopfbereich ist nicht
  /// scrollbar, deshalb darf die Anzeige ihre Höhe nicht ausdehnen. Laufen mehr
  /// als zwei Features, nennt sie die ersten beiden und die Restanzahl.
  Widget _buildActiveFeaturesInfo(ThemeData theme, AppLocalizations l10n) {
    final now = DateTime.now();
    final labels = <String>[];
    for (final entry in _profile.staffEntries) {
      final status = managementFeatureStatusLine(
        l10n,
        entry,
        now,
        sabotageAppliedUntil: _profile.sabotageAppliedUntil,
      );
      if (status == null) continue;
      final label = managementFeatureLabelFor(l10n, entry.activeFeature ?? '');
      labels.add('${entry.name} · ${label ?? entry.role} · $status');
    }
    if (labels.isEmpty) return const SizedBox.shrink();
    final shown = labels.take(2).join('   ·   ');
    final extra = labels.length - 2;
    final text = extra > 0
        ? '${l10n.activeFeaturesTitle}: $shown (+$extra)'
        : '${l10n.activeFeaturesTitle}: $shown';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  /// „Platz X von Y in `<Stadtteil>`“ (Kapitel 12, 4.1/4).
  ///
  /// Wird ohne fälligen Tick aus dem aktuellen Snapshot abgeleitet (idempotent,
  /// `PowerProjectionState`) und nur angezeigt, wenn ein Stadtteil bekannt ist.
  Widget _buildRankingBadge(ThemeData theme, AppLocalizations l10n) {
    final district = _profile.activeDistrict;
    if (district == null || district.isEmpty) return const SizedBox.shrink();
    final pp = GameClockService.powerProjectionState(
      _profile.activeRestaurantSnapshot(),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.emoji_events,
              size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.rankingBadge(pp.playerRank, pp.standings.total, district),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.restaurantName.isNotEmpty
            ? _profile.restaurantName
            : l10n.restaurant),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.renameRestaurant,
            onPressed: () => _showEditRestaurantNameDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.switchRestaurant,
            onPressed: () => _showSwitchRestaurantDialog(context),
          ),
          IconButton(
            icon: Icon(
              switch (AppTheme.themeModeNotifier.value) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.settings_brightness,
              },
            ),
            tooltip: l10n.themeToggle(AppTheme.themeModeNotifier.value.name),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _profile.hasCustomImage
                        ? Image.file(
                            // P6: Legacy-Relativpfade werden aufgelöst.
                            File(ProfileStorage.absolutePath(
                                _profile.headerImagePath)),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: _buildImageErrorWidget,
                          )
                        : Image.asset(
                            _profile.headerImagePath,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: _buildImageErrorWidget,
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        tooltip: l10n.changeProfileImage,
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profile.name.isNotEmpty ? _profile.name : l10n.player,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.group_add),
                  tooltip: l10n.managePersonnel,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScreenHireAndFire()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  l10n.budgetLabel(_profile.budget),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _profile.budget < 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
            if (_profile.activeDistrict != null &&
                _profile.activeDistrict!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.districtLabel(_profile.activeDistrict!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Kapitel 14 (FRT): Korruptionsanzeige des Stadtteils. Bei einem
            // verlorenen Stadtteil als Warnung eingefärbt.
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.corruptionLabel(_profile.corruptionPercent.round()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _profile.districtLost
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight:
                      _profile.districtLost ? FontWeight.bold : null,
                ),
              ),
            ),
            _buildEconomyInfo(theme),
            _buildCuisineRow(theme, l10n),
            _buildRankingBadge(theme, l10n),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(text: l10n.tabPersonnel),
              Tab(text: l10n.tabMedics),
              Tab(text: l10n.tabUpgrades),
              Tab(text: l10n.tabBattle),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonnelTab(theme, l10n),
                _buildMedicsTab(theme, l10n),
                _buildUpgradesTab(theme, l10n),
                _buildBattleTab(theme, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reiter „Aktives Personal": Personal-Liste + Anheuern.
  Widget _buildPersonnelTab(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Text(
              l10n.personnelCount(_profile.personalCount),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_profile.personal.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      l10n.noPersonnelYet,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              _buildSortedPersonnelList(theme, l10n),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: Text(l10n.hireNewPersonnel),
              onPressed: () async {
                final success = _profile.hireApprentice();
                if (!success) {
                  final l10n = AppLocalizations.of(context)!;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.notEnoughBudget)),
                  );
                }
                setState(() {});
                await _saveState();
              },
            ),
        ],
      ),
    );
  }

  /// Reiter „Teamarzt": angeheuerte Ärzte + Verwaltung.
  Widget _buildMedicsTab(ThemeData theme, AppLocalizations l10n) {
    final medics = _profile.hiredMedics;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.personnelManagement, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (medics.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    l10n.noCandidatesAvailable,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            for (final medic in medics)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.medical_services),
                  title: Text(medic.displayName),
                  subtitle: Text(l10n.costPerWeek(medic.costPerWeek)),
                ),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.group_add),
            label: Text(l10n.managePersonnel),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScreenHireAndFire()),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// Reiter „Erweiterungen".
  Widget _buildUpgradesTab(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildUpgradesSection(theme, l10n),
    );
  }

  /// Karte „Rivalen in diesem Gefecht" (Kapitel 13, Q8/Q9).
  ///
  /// Zeigt deterministisch, welche Rivalen mit welcher Stance und Truppenstärke
  /// antreten (identisch zur späteren Gefechtsverteilung, V8/P4).
  Widget _buildBattleRivalsCard(ThemeData theme, AppLocalizations l10n) {
    final district = _profile.activeDistrict;
    if (district == null || district.isEmpty) return const SizedBox.shrink();
    final snapshot = _profile.activeRestaurantSnapshot();
    final pp = GameClockService.powerProjectionState(snapshot);
    final participants = RivalService.battleParticipants(
      snapshot,
      playerPp: pp.powerProjection,
      availableSpawns: EconomyBalance.rivalBattlePlayerSpawnCount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.battleRivalsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (participants.isEmpty)
              Text(
                l10n.battleRivalsNone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final p in participants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    l10n.battleRivalRow(
                      p.name,
                      _stanceLabel(l10n, p.stance),
                      p.teamSize,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Reiter „Karte & Gefecht": Karten-Auswahl + Gefechtsbutton.
  Widget _buildBattleTab(ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Text(
              l10n.availableMaps,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_isLoadingMaps)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mapLoadingError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    l10n.mapLoadError(_mapLoadingError!),
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_mapEntries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      l10n.noMapsFound,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _mapEntries.length,
                itemBuilder: (context, index) {
                  return _buildMapTile(index, _mapEntries[index], theme);
                },
              ),
            const SizedBox(height: 8),
            _buildBattleRivalsCard(theme, l10n),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startBattle),
              onPressed:
                  _battleReadyCharacters.isNotEmpty && _mapEntries.isNotEmpty
                      ? _goToBattle
                      : null,
            ),
        ],
      ),
    );
  }
}
