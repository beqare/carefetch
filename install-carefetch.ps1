# install-carefetch.ps1
# Installation Script für CareFetch

param(
    [switch]$ForceColor = $false
)

function Install-CareFetch {
    Write-Host "CareFetch Installer" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    # Prüfe auf Administrator-Rechte
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "Hinweis: Für eine systemweite Installation werden Administratorrechte benötigt." -ForegroundColor Yellow
        Write-Host "Du kannst trotzdem eine benutzerspezifische Installation durchführen." -ForegroundColor Yellow
    }
    
    # Zielverzeichnis wählen
    if ($isAdmin) {
        $installDir = "$env:ProgramFiles\CareFetch"
        $profileTarget = "Alle Benutzer"
    }
    else {
        $installDir = "$env:LOCALAPPDATA\CareFetch"
        $profileTarget = "Nur aktueller Benutzer"
    }
    
    Write-Host "`nInstallation für: $profileTarget" -ForegroundColor Green
    
    # Verzeichnis erstellen
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        Write-Host "Verzeichnis erstellt: $installDir" -ForegroundColor Green
    }
    
    # CareFetch-Skript kopieren (angenommen, es ist im gleichen Verzeichnis)
    $scriptPath = Join-Path $PSScriptRoot "carefetch.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Fehler: carefetch.ps1 nicht gefunden!" -ForegroundColor Red
        Write-Host "Bitte platziere das Installationsskript im gleichen Verzeichnis wie carefetch.ps1" -ForegroundColor Yellow
        pause
        exit 1
    }
    
    $destPath = Join-Path $installDir "carefetch.ps1"
    Copy-Item -Path $scriptPath -Destination $destPath -Force
    Write-Host "CareFetch-Skript kopiert: $destPath" -ForegroundColor Green
    
    # Systempfad erweitern
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($pathVar -notlike "*$installDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$pathVar;$installDir", "User")
        Write-Host "Pfad-Variable aktualisiert" -ForegroundColor Green
    }
    
    # Batch-Datei erstellen (für cmd.exe)
    $batPath = Join-Path $installDir "carefetch.bat"
    @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0carefetch.ps1" %*
"@ | Set-Content -Path $batPath
    
    Write-Host "Batch-Datei erstellt: $batPath" -ForegroundColor Green
    
    # PowerShell-Profil aktualisieren
    $profilePath = $PROFILE.CurrentUserAllHosts
    
    # Stelle sicher, dass das Profil-Verzeichnis existiert
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Füge Alias zum PowerShell-Profil hinzu
    $aliasCommand = @"

# CareFetch Alias
function global:carefetch {
    param(
        [switch]`$ForceColor = `$false
    )
    
    & "$destPath" @PSBoundParameters
}

Set-Alias -Name cf -Value carefetch -Scope Global -ErrorAction SilentlyContinue
"@
    
    # Prüfe, ob das Alias bereits existiert
    $profileContent = ""
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
    }
    
    if ($profileContent -notlike "*function global:carefetch*") {
        Add-Content -Path $profilePath -Value $aliasCommand
        Write-Host "Alias zum PowerShell-Profil hinzugefügt" -ForegroundColor Green
    }
    else {
        Write-Host "CareFetch ist bereits im PowerShell-Profil registriert" -ForegroundColor Yellow
    }
    
    Write-Host "`nInstallation abgeschlossen!" -ForegroundColor Green
    Write-Host "Du kannst jetzt folgende Befehle verwenden:" -ForegroundColor Cyan
    Write-Host "  - In PowerShell: 'carefetch' oder 'cf'" -ForegroundColor White
    Write-Host "  - In CMD: 'carefetch'" -ForegroundColor White
    Write-Host "`nStarte eine neue PowerShell-Sitzung oder führe aus: . `$PROFILE" -ForegroundColor Yellow
    
    # Optional: Jetzt direkt testen
    $test = Read-Host "`nMöchtest du CareFetch jetzt testen? (J/N)"
    if ($test -eq 'J' -or $test -eq 'j') {
        Write-Host "`nTeste CareFetch..." -ForegroundColor Cyan
        & $destPath
    }
}

# Installation starten
Install-CareFetch