# install.ps1 - Remote Installation Script for CareFetch
# Download: iwr -useb https://raw.githubusercontent.com/beqare/carefetch/refs/heads/main/install.ps1 | iex

param(
    [switch]$ForceColor = $false
)

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "           CAREFETCH INSTALLER           " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Install CareFetch" -ForegroundColor Green
    Write-Host "[2] Repair Installation" -ForegroundColor Yellow
    Write-Host "[3] Uninstall CareFetch" -ForegroundColor Red
    Write-Host "[0] Exit" -ForegroundColor Gray
    Write-Host ""
}

function Get-InstallationPath {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        return "$env:ProgramFiles\CareFetch"
    }
    else {
        return "$env:LOCALAPPDATA\CareFetch"
    }
}

function Get-InstallStatus {
    $installPath = Get-InstallationPath
    $scriptPath = Join-Path $installPath "carefetch.ps1"
    $batPath = Join-Path $installPath "carefetch.bat"
    
    return @{
        Installed = (Test-Path $scriptPath) -and (Test-Path $batPath)
        Path      = $installPath
        IsAdmin   = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

function Install-CareFetch {
    param([bool]$RepairMode = $false)
    
    $status = Get-InstallStatus
    $installPath = $status.Path
    
    if ($RepairMode -and -not $status.Installed) {
        Write-Host "Cannot repair - CareFetch is not installed!" -ForegroundColor Red
        Start-Sleep -Seconds 3
        return
    }
    
    if (-not $RepairMode -and $status.Installed) {
        Write-Host "CareFetch is already installed!" -ForegroundColor Yellow
        $confirm = Read-Host "Do you want to reinstall? (y/N)"
        if ($confirm -notmatch '^[Yy]$') {
            return
        }
    }
    
    # Create installation directory
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        Write-Host "Created installation directory: $installPath" -ForegroundColor Green
    }
    
    # Download carefetch.ps1 from GitHub
    $scriptUrl = "https://raw.githubusercontent.com/beqare/carefetch/refs/heads/main/carefetch.ps1"
    $scriptPath = Join-Path $installPath "carefetch.ps1"
    
    try {
        Write-Host "Downloading carefetch.ps1..." -ForegroundColor Cyan
        Invoke-RestMethod -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
        Write-Host "Downloaded carefetch.ps1 successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download carefetch.ps1: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds 3
        return
    }
    
    # Create command shims for cmd compatibility (.cmd and .bat)
    $cmdPath = Join-Path $installPath "carefetch.cmd"
    $batPath = Join-Path $installPath "carefetch.bat"

    # Robust shim: prefer script in the same folder as the shim (%~dp0),
    # fall back to ProgramFiles/LOCALAPPDATA locations.
    $shim = @'
@echo off
rem CareFetch shim - locates carefetch.ps1 and runs it with PowerShell
set "TARGET=%~dp0carefetch.ps1"
rem If first argument is --setup, run remote installer directly
set "ARG=%~1"
if /I "%ARG%"=="--setup" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb 'https://raw.githubusercontent.com/beqare/carefetch/refs/heads/main/install.ps1' | iex"
    exit /b %ERRORLEVEL%
)
if not exist "%TARGET%" (
    if exist "%ProgramFiles%\CareFetch\carefetch.ps1" set "TARGET=%ProgramFiles%\CareFetch\carefetch.ps1"
    if exist "%LOCALAPPDATA%\CareFetch\carefetch.ps1" set "TARGET=%LOCALAPPDATA%\CareFetch\carefetch.ps1"
)
if not exist "%TARGET%" (
    echo CareFetch script not found: "%TARGET%"
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
'
'@

    $shim | Set-Content -Path $cmdPath -Encoding ASCII
    Copy-Item -Path $cmdPath -Destination $batPath -Force
    Write-Host "Created carefetch.cmd (+ carefetch.bat) for CMD compatibility" -ForegroundColor Green
    
    # Add to PATH if not already present (User scope)
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($pathVar -notlike "*$installPath*") {
        if ([string]::IsNullOrWhiteSpace($pathVar)) {
            $newPath = $installPath
        }
        else {
            $newPath = "$pathVar;$installPath"
        }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "Added installation directory to PATH" -ForegroundColor Green
    }
    else {
        Write-Host "PATH already contains installation directory" -ForegroundColor Yellow
    }

    # Warn if a shadowing file named 'carefetch' (no extension) exists earlier in PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User") -split ';' | Where-Object { $_ }
    $allPath = ([Environment]::GetEnvironmentVariable("PATH", "Machine") , $userPath) -join ';' -split ';' | Where-Object { $_ }
    foreach ($p in $allPath) {
        try {
            $candidate = Join-Path $p 'carefetch'
            if ((Test-Path $candidate) -and -not ($candidate -eq (Join-Path $installPath 'carefetch.cmd')) -and -not ($candidate -eq (Join-Path $installPath 'carefetch.bat'))) {
                Write-Host "Warning: A file named 'carefetch' exists in PATH at: $candidate`nIt may shadow the created shim. Consider removing or renaming it." -ForegroundColor Yellow
                break
            }
        }
        catch { }
    }
    
    # Update PowerShell profile (CurrentUserAllHosts)
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Define function that resolves path at runtime (safe for admin/non-admin)
    $aliasFunction = @"
# CareFetch Function
function global:carefetch {
    param(
        [switch]`$ForceColor = `$false
    )
    # Resolve install path dynamically at runtime
    `$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (`$isAdmin) {
        `$installPath = "`$env:ProgramFiles\CareFetch"
    } else {
        `$installPath = "`$env:LOCALAPPDATA\CareFetch"
    }
    `$scriptPath = Join-Path `$installPath "carefetch.ps1"
    if (-not (Test-Path `$scriptPath)) {
        Write-Error "CareFetch not found at `$scriptPath. Run installer or repair."
        return 1
    }
    & `$scriptPath @PSBoundParameters
}

Set-Alias -Name cf -Value carefetch -Scope Global -ErrorAction SilentlyContinue
"@

    # Read current profile (or empty if none)
    $profileContent = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { "" }

    # Remove any old CareFetch section to prevent duplicates
    $profileContent = $profileContent -replace "(?s)# CareFetch Function.*?Set-Alias -Name cf.*?`n`n?", ""

    # Write back cleaned profile
    Set-Content -Path $profilePath -Value $profileContent.Trim() -Force -ErrorAction SilentlyContinue

    # Append new definition
    Add-Content -Path $profilePath -Value "`n$aliasFunction" -Encoding UTF8
    Write-Host "Added (or updated) function and alias in PowerShell profile" -ForegroundColor Green
    
    if ($RepairMode) {
        Write-Host "`nRepair completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
    }
    
    Write-Host "You can now use:" -ForegroundColor Cyan
    Write-Host "  - In PowerShell: 'carefetch' or 'cf'" -ForegroundColor White
    Write-Host "  - In CMD: 'carefetch'" -ForegroundColor White
    Write-Host "`nNote: Restart your terminal or run '. `$PROFILE' to apply changes immediately." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 3
}

function Uninstall-CareFetch {
    $status = Get-InstallStatus
    
    if (-not $status.Installed) {
        Write-Host "CareFetch is not installed!" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        return
    }
    
    Write-Host "Uninstalling CareFetch from: $($status.Path)" -ForegroundColor Red
    $confirm = Read-Host "Are you sure you want to uninstall? (y/N)"
    
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Uninstall cancelled" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    # Remove from PowerShell profile
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw
        # Remove entire CareFetch block
        $newContent = $content -replace "(?s)# CareFetch Function.*?Set-Alias -Name cf.*?`n`n?", ""
        $newContent = $newContent.Trim()
        Set-Content -Path $profilePath -Value $newContent -Force
        Write-Host "Removed CareFetch from PowerShell profile" -ForegroundColor Green
    }
    
    # Remove from PATH
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    $paths = $pathVar -split ';' | Where-Object { $_ -and $_ -notlike "*CareFetch*" }
    $newPath = $paths -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "Removed CareFetch from PATH" -ForegroundColor Green
    
    # Delete installation directory
    try {
        Remove-Item -Path $status.Path -Recurse -Force
        Write-Host "Deleted installation directory" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not delete install directory (may be in use)" -ForegroundColor Yellow
    }
    
    Write-Host "`nUninstallation completed!" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

# Main execution
do {
    Show-Menu
    $choice = Read-Host "Enter your choice [0-3]"
    
    switch ($choice.Trim()) {
        '1' {
            Install-CareFetch -RepairMode $false
        }
        '2' {
            Install-CareFetch -RepairMode $true
        }
        '3' {
            Uninstall-CareFetch
        }
        '0' {
            Write-Host "Exiting installer..." -ForegroundColor Gray
            break
        }
        default {
            Write-Host "Invalid choice. Please enter 0-3." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '0')