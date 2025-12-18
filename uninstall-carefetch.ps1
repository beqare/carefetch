# uninstall-carefetch.ps1

function Uninstall-CareFetch {
    Write-Host "CareFetch Deinstaller" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    # Prüfe auf Administrator-Rechte
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # Mögliche Installationsverzeichnisse
    $possibleDirs = @(
        "$env:LOCALAPPDATA\CareFetch",
        "$env:ProgramFiles\CareFetch"
    )
    
    $foundDir = $null
    foreach ($dir in $possibleDirs) {
        if (Test-Path $dir) {
            $foundDir = $dir
            break
        }
    }
    
    if (-not $foundDir) {
        Write-Host "CareFetch ist nicht installiert." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Gefundenes Installationsverzeichnis: $foundDir" -ForegroundColor Green
    
    # Aus dem PowerShell-Profil entfernen
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw
        $newContent = $content -replace "(?s)# CareFetch Alias.*?Set-Alias -Name cf -Value carefetch.*?`n", ""
        if ($content -ne $newContent) {
            Set-Content -Path $profilePath -Value $newContent -Force
            Write-Host "CareFetch aus PowerShell-Profil entfernt" -ForegroundColor Green
        }
    }
    
    # Aus PATH entfernen
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    $newPath = ($pathVar -split ';' | Where-Object { $_ -notlike "*CareFetch*" }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    
    # Verzeichnis löschen
    Remove-Item -Path $foundDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "CareFetch erfolgreich deinstalliert" -ForegroundColor Green
}

Uninstall-CareFetch