# Der erste Prototyp

Der erste Prototyp steht an. **Ziel:** Eine auslieferbare, testbare Version des Spiels für Windows, Linux und Android inklusive automatisierter CI/CD-Pipeline.

Der aktuelle Stand (Version `0.1.0+1`) ist ein reines Entwicklungsprojekt ohne Build-Pipeline, ohne Release-Prozess und ohne dokumentierte Teststrategie. Dieses Dokument definiert die konkreten Schritte zum ersten öffentlichen Prototyp.

---

## Arbeitspakete

### 1. 🖥️ Plattform-Konfiguration

Der Prototyp soll vorerst nur unter **Windows**, **Linux** und **Android** released werden. Jede Plattform braucht spezifische Konfiguration.

- [x] **Windows** – MSIX-/EXE-Build vorbereiten
  - ✅ `Runner.rc`: Metadaten aktualisiert (CompanyName → "TiledWare Studios", ProductName → "Tiled Warfare", Description, Copyright)
  - ✅ `msix_config` in `pubspec.yaml` ergänzt (`display_name: "Tiled Warfare"`, `publisher_display_name: "TiledWare Studios"`, `identity_name: "TiledWareStudios.TiledWarfare"`, Icon-Pfade, `architecture: x64`)
  - ✅ `windows/runner/resources/app_icon.ico` vorhanden und referenziert
- [x] **Linux** – AppImage/Snap-Build vorbereiten
  - ✅ `linux/CMakeLists.txt`: `APPLICATION_ID` geändert von `com.example.tiled_warfare` → `com.tiledware.tiled_warfare`
  - ✅ `linux/runner/my_application.cc`: Fenstertitel `"tiled_warfare"` → `"Tiled Warfare"` (HeaderBar + fallback)
  - [ ] Installationsskript oder Flatpak-Manifest erwägen *(optional, für später)*
- [x] **Android** – APK/AAB-Build vorbereiten
  - ✅ `android/app/build.gradle.kts`: `namespace` und `applicationId` auf `com.tiledware.tiled_warfare`, `versionCode = 1`, `versionName = "0.1.0"`, `minSdk = 21`
  - ✅ `AndroidManifest.xml`: `android:label` auf `"Tiled Warfare"` gesetzt
  - ✅ Android Icons (`ic_launcher.png`) in allen mipmap-Verzeichnissen vorhanden
  - ✅ Debug-Keystore existiert unter `%USERPROFILE%\.android\debug.keystore`
  - [ ] Release-Keystore für Produktion erstellen *(wenn CI/CD eingerichtet wird)*

### 2. 🏗️ Build-Setup für `pubspec.yaml`

Bevor die CI/CD-Pipeline gebaut wird, muss das Projekt lokal fehlerfrei builden.

- [x] `flutter build windows --release` ✅ (103,7s – `build\windows\x64\runner\Release\tiled_warfare.exe`)
- [ ] `flutter build linux --release` (nicht getestet – Linux-Build-Umgebung erforderlich)
- [x] `flutter build apk --release` ✅ (292,7s – `build\app\outputs\flutter-apk\app-release.apk`, 51,4MB)
- [x] Build-Befehle in `scripts/build.ps1` dokumentiert

### 3. 🔄 CI/CD-Workflow (GitHub Actions)

GitHub muss so konfiguriert werden, dass bei einem Push in den `main`-Branch automatisch ein **Release-Build** erstellt wird, und bei Push in andere Branches ein **Nightly-Build**.

- [x] `.github/workflows/release.yml` erstellt
  - Trigger: `push` auf `main`
  - Matrix-Build für `windows-latest`, `ubuntu-latest`, `android`
  - Test-Job vorgeschaltet (`flutter test` + `flutter analyze`)
  - Artefakte via `actions/upload-artifact@v4`
  - GitHub Release (draft + prerelease) via `softprops/action-gh-release@v2`
  - Format: `tiled_warfare-v{VERSION}-{PLATFORM}.{ext}`
- [x] `.github/workflows/nightly.yml` erstellt
  - Trigger: `push` auf alle Branches außer `main`
  - Gleicher Build-Prozess ohne Test-Job (schneller für Nightly)
  - Artefakt-Namen: `tiled_warfare-nightly-{BRANCH}-{RUN_ID}-{PLATFORM}`
  - Artefakte als GitHub Actions Artefakt gespeichert
- [ ] **Secrets** hinterlegen *(muss nach erstem Release-Build erfolgen)*
  - `ANDROID_KEYSTORE_BASE64` – Base64-kodierter Keystore
  - `ANDROID_KEYSTORE_PASSWORD` – Keystore-Passwort
  - `ANDROID_KEY_PASSWORD` – Key-Passwort
  - `ANDROID_KEY_ALIAS` – Key-Alias
  - Aktuell: Debug-Signierung aktiv (für Prototyp ausreichend)

### 4. 📦 Release-Namenskonvention

Einheitliche Benennung der Build-Artefakte, damit Tester sofort erkennen, um welche Version es sich handelt.

```text
Release (main):
  tiled_warfare-v0.1.0-windows.exe
  tiled_warfare-v0.1.0-linux.AppImage
  tiled_warfare-v0.1.0-android.apk

Nightly (non-main):
  tiled_warfare-nightly-feature-battle-anim-20260714-windows.exe
  tiled_warfare-nightly-feature-battle-anim-20260714-linux.AppImage
  tiled_warfare-nightly-feature-battle-anim-20260714-android.apk
```

✅ Die Namenskonvention wird in den CI/CD-Workflows `release.yml` und `nightly.yml` verwendet.

### 5. 📖 README.md aktualisieren

Die `README.md` enthält derzeit nur einen Platzhalter ("A new Flutter project"). Sie muss auf die ausführbaren Dateien verweisen und grundlegende Informationen enthalten.

- [x] README.md komplett neu geschrieben:
  - ✅ Projektbeschreibung (DE)
  - ✅ Download-Tabelle mit Links zu GitHub Actions
  - ✅ Systemanforderungen für Windows/Linux/Android
  - ✅ Build-Befehle lokal + via Build-Skript
  - ✅ Projektstruktur-Übersicht
  - ✅ CI/CD-Workflow-Tabelle
  - ✅ Lizenz- und Kontaktabschnitt
- [ ] Download-Links aktualisieren, sobald erster GitHub Release erstellt wurde
- [ ] Screenshots/GIFs des aktuellen Spielstands einfügen (sobald vorhanden)

### 6. 🧪 Teststrategie für den Prototyp

- [x] **Manuelle Testfälle** dokumentiert → `doc/tests/test_cases_prototype.md`
  - ✅ 12 Testfälle mit Schritt-für-Schritt-Aktionen und erwarteten Ergebnissen
  - ✅ Abdeckung: App-Start, Karte, Token-Bewegung, Kampf, Angriff, Runden, Team, Speichern/Laden
  - ✅ Fehlerprotokoll-Vorlage für Tester
- [ ] **Automatisierte Tests** erweitern (für CI/CD-Pipeline)
  - `flutter test` ist bereits im `release.yml`-Workflow enthalten
  - Aktuell: **keine** `*_test.dart`-Dateien vorhanden → später hinzufügen
- [x] **Feedback-Prozess** definiert (am Ende von `doc/tests/test_cases_prototype.md`)
  - Fehler über GitHub Issues melden: `https://github.com/Reyneke/TiledWarfare/issues`
  - Vorlage für Fehlerprotokoll (Datum, Tester, Testfall, Schritt, Beschreibung, Screenshot)

### 7. 🎯 Fehlende Kernfunktionen identifizieren

Analyse des aktuellen Codebestands (Stand: 14.07.2026):

**Vorhanden:** Startbildschirm ✅, Restaurant-UI ✅, Team-Verwaltung ✅, Karten-Loader ✅, Kampf-Screen `ScreenMain` ✅, Token ✅, Spieler/Gegner-Objekte ✅, Teamarzt ✅, Profil-Speicherung ✅, L10n (DE/EN) ✅

**Noch nicht vorhanden / Lücken:**

### ✅ Bereits implementiert

- [x] **Kampf-Ergebnis-Bildschirm** → `lib/screens/screen_battle_result.dart`
  - Zeigt Sieg/Niederlage mit Icon + Text
  - Listet alle Einheiten mit XP-Gewinn und Levelaufstiegen
  - Navigiert zurück zum Restaurant via `popUntil(isFirst)`
- [x] **XP-Vergabe nach Kampf** → `_calculateXp()` im Ergebnis-Bildschirm
  - Sieg: 50 + 10 × Level XP pro Einheit
  - Niederlage: 10 XP pro Einheit
  - `earnXP()` wird aufgerufen, Levelaufstiege werden im UI angezeigt
- [x] **Globale Fehlerbehandlung + Logging** → `lib/services/crash_logger.dart`
  - `FlutterError.onError` abgefangen → in Log-Datei geschrieben
  - `PlatformDispatcher.instance.onError` abgefangen → in Log-Datei geschrieben
  - `lib/main.dart` initialisiert `CrashLogger` beim App-Start
  - Log-Datei unter `logs/crash_YYYY-MM-DD.log`
  - Tester können Log-Datei an Bug-Report anhängen
- [x] **Spiel-Ende-Erkennung** (war bereits im `WidgetCaretaker`)
  - `widget.onGameOver?.call(!_player.unitList.isEmpty)` bei Zeile 1438
  - Navigiert jetzt zum Ergebnis-Bildschirm statt nur zu syncing

### ⏳ Für später geplant (als Epic-Datei dokumentiert)

- [ ] **Escape/Rückzug aus Kampf** → `doc/epics/prototyp_erweiterungen.md`
- [ ] **Mehrere Karten** → `doc/epics/prototyp_erweiterungen.md`
- [ ] **Tutorial/Anleitung** → `doc/epics/prototyp_erweiterungen.md`
- [ ] **Beute/Belohnungssystem** → `doc/epics/prototyp_erweiterungen.md`
- [ ] **Speicherfunktion für Kampfzustand** – Kampfzustand (Token-Positionen, HP-Verluste) wird noch nicht persistiert
- [ ] **Team-Zusammenstellung vor Kampf** – Separater Screen fehlt
- [ ] **Automatisierte Unit-Tests** – Keine `*_test.dart`-Dateien vorhanden
- [ ] **macOS/iOS/Web-Build** – Derzeit nicht konfiguriert

---

## Definition of Done

Ein Arbeitspaket gilt als abgeschlossen, wenn:

- alle Sub-Aufgaben abgehakt sind,
- der Build für alle drei Zielplattformen lokal fehlerfrei durchläuft,
- die CI/CD-Pipeline auf GitHub mindestens einmal erfolgreich durchgelaufen ist,
- die README.md aktualisiert und die Download-Links funktionieren,
- und mindestens ein manueller Testdurchlauf erfolgreich war.

---

## Ressourcen

- [GitHub Actions für Flutter](https://docs.flutter.dev/deployment/cd)
- [Flutter Windows Build](https://docs.flutter.dev/platform-integration/windows/building)
- [Flutter Linux Build](https://docs.flutter.dev/platform-integration/linux/building)
- [Flutter Android Build](https://docs.flutter.dev/deployment/android)
- [MSIX-Konfiguration für Flutter](https://pub.dev/packages/msix)