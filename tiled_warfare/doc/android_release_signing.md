# Android Release-Signatur

Diese Anleitung erklärt, wie der APK mit einer Release-Signatur versehen wird – sowohl **lokal** als auch **auf GitHub Actions**.

---

## 📂 Keystore-Struktur

```
tiled_warfare/
├── android/
│   ├── app/
│   │   └── build.gradle.kts   ← Konfiguration für Signatur
│   ├── release-keystore.jks    ← KEIN CHECK-IN! (in .gitignore)
│   └── ...
```

Der Keystore `android/release-keystore.jks` wurde bereits mit diesen Werten erstellt:

| Eigenschaft | Wert |
|-------------|------|
| Datei | `android/release-keystore.jks` |
| Passwort (store) | `android` |
| Key-Alias | `tiled_warfare` |
| Key-Passwort | `android` |
| Gültig bis | ~27 Jahre |

> ⚠️ Für einen **echten Release** solltest du eigene Passwörter wählen!  
> Du kannst jederzeit einen neuen Keystore erstellen (siehe Schritt 0).

---

## Variante A: Lokalen APK signieren

### Schritt 0 (optional): Eigenen Keystore erstellen

Nur nötig, wenn du eigene Passwörter willst:

```bash
# Im Projektverzeichnis ausführen:
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" ^
  -genkey -v ^
  -keystore android/release-keystore.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 ^
  -alias tiled_warfare ^
  -storepass MEIN_PASSWORT ^
  -keypass MEIN_PASSWORT
```

Ersetze `MEIN_PASSWORT` durch dein eigenes.

### Schritt 1: Build-Script anpassen

`android/app/build.gradle.kts` öffnen und den Bereich `buildTypes { release { ... } }` so ändern:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")  // ← Aktivieren
    }
}
```

**Vorher:** `signingConfig = signingConfigs.getByName("debug")`  
**Nachher:** `signingConfig = signingConfigs.getByName("release")`

Das `signingConfigs { create("release") { ... } }` weiter unten ist bereits fertig konfiguriert.

### Schritt 2: Signierten APK bauen

```bash
flutter build apk --release
```

Der APK liegt dann in:
```
build/app/outputs/flutter-apk/app-release.apk
```

Testen mit:
```bash
# Prüfen ob die Signatur stimmt (im android-Verzeichnis):
"C:\Program Files\Android\Android Studio\jbr\bin\apksigner.bat" verify ..\..\build\app\outputs\flutter-apk\app-release.apk
```

---

## Variante B: GitHub Actions (CI/CD) mit signiertem APK

Für automatische Builds auf GitHub brauchst du den Keystore als **Base64-kodiertes Secret**.

### Schritt 1: Keystore als Base64 exportieren

```bash
# Base64-Datei erzeugen (nur einmal nötig):
certutil -encode android\release-keystore.jks android\release-keystore.b64

# Inhalt für GitHub kopieren:
type android\release-keystore.b64
# → Kopiere den gesamten Inhalt (mit den BEGIN/END-Zeilen!)
```

Für Linux/Mac:
```bash
base64 -i android/release-keystore.jks
```

### Schritt 2: GitHub Secrets anlegen

Gehe zu: **GitHub → Repository → Settings → Secrets and variables → Actions**

Lege diese 4 Secrets an:

| Secret-Name | Wert |
|-------------|------|
| `ANDROID_KEYSTORE_BASE64` | Komplette Base64-Ausgabe aus Schritt 1 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore-Passwort (z. B. `android`) |
| `ANDROID_KEY_PASSWORD` | Key-Passwort (z. B. `android`) |
| `ANDROID_KEY_ALIAS` | Key-Alias (z. B. `tiled_warfare`) |

### Schritt 3: CI/CD-Workflow erweitern

Die bestehende `release.yml` entschlüsselt den Keystore wie folgt – das muss **vor** dem `flutter build apk` passieren:

```yaml
- name: Decode Android Keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" > android/release-keystore.b64
    certutil -decode android/release-keystore.b64 android/release-keystore.jks
  shell: cmd
```

**Hinweis:** Der `ubuntu-latest` Runner hat kein `certutil`. Für Linux-Worker stattdessen:

```yaml
- name: Decode Android Keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/release-keystore.jks
```

### Schritt 4: Build-Step anpassen

Damit der signierte APK gebaut wird, muss der Build-Step die Umgebungsvariablen bekommen:

```yaml
- name: Build Android APK (signed)
  run: flutter build apk --release
  env:
    ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
```

Wichtig: **Kein** `--android-skip-build-dependency-validation` mehr, da der Build jetzt die volle Validierung durchläuft.

---

## Fehlerbehebung

### "jks file not found"
- Prüfe, ob `android/release-keystore.jks` existiert
- In GitHub Actions: Wird der Keystore im richtigen Schritt decodiert? (vor `flutter build apk`)

### "Password may be incorrect"
- `storepass` im keytool-Befehl und `storePassword` in `build.gradle.kts` müssen übereinstimmen
- In GitHub Actions: Stimmen die Secrets mit den tatsächlichen Passwörtern überein?

### "Keystore was tampered with, or password was incorrect"
- Base64-Codierung fehlerhaft → nochmal mit `certutil -encode` exportieren
- In GitHub Actions: Enthält das Secret die vollständige Base64-Ausgabe (mit Header/Footer)?

---

## Sicherheitshinweise

| ✅ Richtlinie | ❌ Vermeiden |
|--------------|--------------|
| `release-keystore.jks` in `.gitignore` | Keystore in Git einchecken |
| Eigenes Passwort für echten Release | Standardpasswort `android` verwenden |
| Keystore-Backup anlegen | Nur eine Kopie haben |
| Base64-Secret in GitHub verschlüsselt | Secret in Logs oder Code ausgeben |

---

## Kurzreferenz (PowerShell-Befehle)

```powershell
# Neuen Keystore erstellen (mit eigenen Passwörtern)
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore android/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tiled_warfare -storepass MEIN_PASS -keypass MEIN_PASS

# Keystore als Base64 exportieren (für GitHub)
certutil -encode android\release-keystore.jks android\release-keystore.b64
notepad android\release-keystore.b64  # → Inhalt in GitHub Secret kopieren

# APK-Signatur verifizieren
& "C:\Program Files\Android\Android Studio\jbr\bin\apksigner.bat" verify build\app\outputs\flutter-apk\app-release.apk