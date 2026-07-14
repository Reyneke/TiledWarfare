# Tiled Warfare

Ein taktisches Rundenkampf-Spiel auf einem hexagonalen Raster, entwickelt mit Flutter.

> 🚧 **Prototyp-Phase** – Dieses Projekt befindet sich in der aktiven Entwicklung.
> Neue Funktionen und Änderungen sind jederzeit möglich.

---

## 📥 Downloads

| Plattform | Stabil (main) | Nächtlich (Nightly) |
|-----------|---------------|---------------------|
| Windows   | *Coming soon* | [Aktionen → Artefakte](https://github.com/Reyneke/TiledWarfare/actions) |
| Linux     | *Coming soon* | [Aktionen → Artefakte](https://github.com/Reyneke/TiledWarfare/actions) |
| Android   | *Coming soon* | [Aktionen → Artefakte](https://github.com/Reyneke/TiledWarfare/actions) |

**Hinweis:** Sobald der erste Release erstellt ist, erscheinen hier direkte Download-Links.
Nightly-Builds sind über **GitHub Actions → Workflow auswählen → Artefakte** abrufbar.

---

## 🚀 Erste Schritte

### Systemanforderungen

- **Flutter SDK** 3.44.6 oder neuer (stable channel)
- **Windows:** Visual Studio 2022 mit C++-Desktop-Workload
- **Linux:** clang, cmake, ninja-build, pkg-config, libgtk-3-dev
- **Android:** Android SDK (API-Level 35) + Android NDK

### Lokal ausführen

```bash
# Abhängigkeiten installieren
flutter pub get

# Im Entwicklungsmodus starten
flutter run -d windows   # oder: linux, android
```

### Release-Build erstellen

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# Android APK
flutter build apk --release --android-skip-build-dependency-validation
```

Oder mit dem Build-Skript:
```powershell
.\scripts\build.ps1 -Platform windows -Mode release
```

---

## 🏗️ Projektstruktur

```
tiled_warfare/
├── android/          # Android-Plattform-Konfiguration
├── assets/           # Sprites, Karten, Screenshots
│   ├── images/
│   └── maps/
├── ios/              # iOS-Plattform (zukünftig)
├── lib/              # Dart-Quellcode
│   ├── animations/
│   ├── fuzzy_logic/
│   ├── l10n/         # Lokalisierung (DE/EN)
│   ├── models/
│   ├── objects/      # Spielobjekte (Spieler, Gegner, Tokens)
│   ├── screens/      # Bildschirme/UI
│   ├── services/
│   ├── theme/
│   ├── utils/
│   └── widgets/
├── linux/            # Linux-Plattform-Konfiguration
├── macos/            # macOS-Plattform (zukünftig)
├── windows/          # Windows-Plattform-Konfiguration
├── doc/              # Dokumentation, Regeln, TODOs
└── scripts/          # Build- und Hilfsskripte
```

---

## 🧪 Tests

```bash
# Alle Tests ausführen
flutter test

# Code-Analyse
flutter analyze
```

Aktuell werden Tests automatisch vor jedem Release-Build in der CI/CD-Pipeline ausgeführt.

---

## 🔄 CI/CD

| Workflow | Trigger | Beschreibung |
|----------|---------|-------------|
| `release.yml` | Push auf `main` | Test → Build (Win/Linux/Android) → GitHub Release (draft) |
| `nightly.yml` | Push auf andere Branches | Build (Win/Linux/Android) → Artefakte auf Actions |

---

## 📄 Lizenz

Dieses Projekt ist lizenziert unter MIT License.

---

## 📬 Kontakt / Feedback

- **Issues:** [GitHub Issues](https://github.com/Reyneke/TiledWarfare/issues)
- **Diskussion:** [GitHub Discussions](https://github.com/Reyneke/TiledWarfare/discussions)