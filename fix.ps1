# Schnellfix für CareFetch Probleme
Write-Host "Bereinige CareFetch Installation..." -ForegroundColor Yellow

# 1. PATH bereinigen
$pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
$cleanPath = ($pathVar -split ';' | Where-Object { 
    $_ -and $_.Trim() -ne "" -and $_ -notlike "*CareFetch*" 
}) -join ';'
[Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
Write-Host "✓ PATH cleaned" -ForegroundColor Green

# 2. Profil bereinigen
$profilePath = $PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $newContent = $content -replace "(?sm)# CareFetch Function.*?Set-Alias.*?`r?`n", ""
    $newContent = $newContent -replace "Set-Alias.*-Name cf.*`r?`n", ""
    
    if ($content -ne $newContent) {
        Set-Content -Path $profilePath -Value $newContent -Force
        Write-Host "✓ PowerShell Profile cleaned" -ForegroundColor Green
    }
}

# 3. Alte Verzeichnisse löschen
$pathsToRemove = @(
    "$env:LOCALAPPDATA\CareFetch",
    "$env:ProgramFiles\CareFetch"
)

foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Programm Path deleted: $path" -ForegroundColor Green
    }
}

Write-Host "`nFinished! Restart terminal to apply." -ForegroundColor Cyan
Pause