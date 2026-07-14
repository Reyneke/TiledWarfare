# Build-Skript für Tiled Warfare
# Verwendung: .\scripts\build.ps1 -Platform <windows|linux|android> -Mode <release|debug>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("windows", "linux", "android", "all")]
    [string]$Platform,

    [Parameter(Mandatory=$false)]
    [ValidateSet("release", "debug", "profile")]
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"

function Build-Platform {
    param([string]$Platform, [string]$Mode)
    
    Write-Host "=== Building $Platform ($Mode) ===" -ForegroundColor Cyan
    
    $outputDir = "build\output\$Platform"
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    
    switch ($Platform) {
        "windows" {
            flutter build windows --$Mode
            Write-Host "Output: build\windows\runner\$Mode\" -ForegroundColor Green
        }
        "linux" {
            flutter build linux --$Mode
            Write-Host "Output: build\linux\runner\$Mode\" -ForegroundColor Green
        }
        "android" {
            flutter build apk --$Mode
            Write-Host "Output: build\app\outputs\flutter-apk\" -ForegroundColor Green
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed for $Platform ($Mode)!" -ForegroundColor Red
        exit 1
    }
}

function Build-All {
    param([string]$Mode)
    Build-Platform -Platform "windows" -Mode $Mode
    Build-Platform -Platform "linux" -Mode $Mode
    Build-Platform -Platform "android" -Mode $Mode
}

# Voraussetzungen prüfen
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Host "Fehler: 'flutter' nicht im PATH gefunden." -ForegroundColor Red
    exit 1
}

Write-Host "Flutter SDK: $(flutter --version | Select-String -Pattern 'Flutter' | ForEach-Object { $_.Line })" -ForegroundColor Gray

# Build ausführen
if ($Platform -eq "all") {
    Build-All -Mode $Mode
} else {
    Build-Platform -Platform $Platform -Mode $Mode
}

Write-Host "=== Build erfolgreich abgeschlossen ===" -ForegroundColor Green