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
    
    # Create batch file for cmd compatibility
    $batPath = Join-Path $installPath "carefetch.bat"
    $batchContent = "@echo off`npowershell -ExecutionPolicy Bypass -File `"%~dp0carefetch.ps1`" %*"
    $batchContent | Set-Content -Path $batPath -Encoding ASCII
    Write-Host "Created carefetch.bat for CMD compatibility" -ForegroundColor Green
    
    # Add to PATH if not already present
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($pathVar -notlike "*$installPath*") {
        [Environment]::SetEnvironmentVariable("PATH", "$pathVar;$installPath", "User")
        Write-Host "Added installation directory to PATH" -ForegroundColor Green
    }
    else {
        Write-Host "PATH already contains installation directory" -ForegroundColor Yellow
    }
    
    # Update PowerShell profile
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    $aliasFunction = @"
# CareFetch Function
function global:carefetch {
    param(
        [switch]`$ForceColor = `$false
    )
    & "`$(`$PSScriptRoot)\carefetch.ps1" @PSBoundParameters
}

Set-Alias -Name cf -Value carefetch -Scope Global -ErrorAction SilentlyContinue
"@

    $profileContent = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { "" }
    
    if ($profileContent -notlike "*# CareFetch Function*") {
        Add-Content -Path $profilePath -Value $aliasFunction
        Write-Host "Added function and alias to PowerShell profile" -ForegroundColor Green
    }
    else {
        Write-Host "PowerShell profile already configured" -ForegroundColor Yellow
    }
    
    if ($RepairMode) {
        Write-Host "`nRepair completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
    }
    
    Write-Host "You can now use:" -ForegroundColor Cyan
    Write-Host "  - In PowerShell: 'carefetch' or 'cf'" -ForegroundColor White
    Write-Host "  - In CMD: 'carefetch'" -ForegroundColor White
    Write-Host "`nNote: You may need to restart your shell or run '. `$PROFILE' to load changes" -ForegroundColor Yellow
    
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
        $newContent = $content -replace "(?s)# CareFetch Function.*?`n", ""
        
        if ($content -ne $newContent) {
            Set-Content -Path $profilePath -Value $newContent -Force
            Write-Host "Removed CareFetch from PowerShell profile" -ForegroundColor Green
        }
    }
    
    # Remove from PATH
    $pathVar = [Environment]::GetEnvironmentVariable("PATH", "User")
    $newPath = ($pathVar -split ';' | Where-Object { $_ -notlike "*CareFetch*" }) -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "Removed CareFetch from PATH" -ForegroundColor Green
    
    # Delete installation directory
    Remove-Item -Path $status.Path -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted installation directory" -ForegroundColor Green
    
    Write-Host "`nUninstallation completed!" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

function Show-Status {
    $status = Get-InstallStatus
    
    Write-Host "Installation Status:" -ForegroundColor Cyan
    Write-Host "  Installed: " -NoNewline
    if ($status.Installed) {
        Write-Host "Yes" -ForegroundColor Green
    }
    else {
        Write-Host "No" -ForegroundColor Red
    }
    
    Write-Host "  Path: $($status.Path)" -ForegroundColor White
    Write-Host "  Admin Mode: $($status.IsAdmin)" -ForegroundColor White
    Write-Host ""
    Pause
}

# Main execution
do {
    Show-Menu
    $choice = Read-Host "Enter your choice [0-3]"
    
    switch ($choice) {
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
        }
        default {
            Write-Host "Invalid choice. Please enter 0-3." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '0')