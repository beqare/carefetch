param(
    [switch]$ForceColor = $false
)

function Get-AccentColor {
    param(
        [switch]$ForceColor = $false
    )

    if (-not $ForceColor -and -not [Console]::IsOutputRedirected) {
        $supportsAnsi = $Host.UI.SupportsVirtualTerminal
        if (-not $supportsAnsi) {
            return ""
        }
    }

    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\DWM"
        $accentColor = Get-ItemProperty -Path $regPath -Name "AccentColor" -ErrorAction Stop
        $colorValue = $accentColor.AccentColor
        $b = ($colorValue -band 0xFF)
        $g = (($colorValue -shr 8) -band 0xFF)
        $r = (($colorValue -shr 16) -band 0xFF)
        return "$([char]27)[38;2;$r;$g;${b}m"
    }
    catch {
        return "$([char]27)[96m"
    }
}

function Get-CimInstanceSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClassName,

        [string]$Filter
    )

    try {
        if ($Filter) {
            return Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop
        }

        return Get-CimInstance -ClassName $ClassName -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-Uptime {
    $os = Get-CimInstanceSafe -ClassName "Win32_OperatingSystem"
    if (-not $os -or -not $os.LastBootUpTime) {
        return "Unknown"
    }

    $uptime = (Get-Date) - $os.LastBootUpTime
    return "{0} days {1} hours {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
}

function Get-SystemDriveLetter {
    $systemDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        return "C:"
    }

    return $systemDrive.TrimEnd('\')
}

function Get-DiskUsage {
    $systemDrive = Get-SystemDriveLetter
    $drive = Get-CimInstanceSafe -ClassName "Win32_LogicalDisk" -Filter "DeviceID='$systemDrive'"
    if (-not $drive -or -not $drive.Size) {
        return @{
            Label = $systemDrive
            Usage = "Unknown"
        }
    }

    $sizeGiB = [math]::Round($drive.Size / 1GB, 2)
    $freeGiB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $usedGiB = [math]::Round($sizeGiB - $freeGiB, 2)
    $percent = if ($sizeGiB -gt 0) { [math]::Round(($usedGiB / $sizeGiB) * 100) } else { 0 }

    return @{
        Label = $systemDrive
        Usage = "$usedGiB GiB / $sizeGiB GiB ($percent%)"
    }
}

function Get-MemoryUsage {
    $os = Get-CimInstanceSafe -ClassName "Win32_OperatingSystem"
    if (-not $os -or -not $os.TotalVisibleMemorySize) {
        return "Unknown"
    }

    $totalMem = [math]::Round(([double]$os.TotalVisibleMemorySize * 1KB) / 1GB, 2)
    $freeMem = [math]::Round(([double]$os.FreePhysicalMemory * 1KB) / 1GB, 2)
    $usedMem = [math]::Round($totalMem - $freeMem, 2)
    $percent = if ($totalMem -gt 0) { [math]::Round(($usedMem / $totalMem) * 100) } else { 0 }

    return "$usedMem GiB / $totalMem GiB ($percent%)"
}

function Get-Resolution {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $screens = [System.Windows.Forms.Screen]::AllScreens
        if (-not $screens) {
            return "Unknown"
        }

        $resolutions = $screens | ForEach-Object { "$($_.Bounds.Width)x$($_.Bounds.Height)" }
        return ($resolutions -join ", ")
    }
    catch {
        return "Unknown"
    }
}

function Get-OSVersionDisplay {
    try {
        $currentVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        if ($currentVersion.DisplayVersion) {
            return $currentVersion.DisplayVersion
        }

        if ($currentVersion.ReleaseId) {
            return $currentVersion.ReleaseId
        }
    }
    catch {
    }

    return "Unknown"
}

function Get-TerminalName {
    if ($env:WT_SESSION) {
        return "Windows Terminal"
    }

    if ($env:TERM_PROGRAM) {
        return $env:TERM_PROGRAM
    }

    if ($Host.Name) {
        return $Host.Name
    }

    return "Unknown"
}

function Get-PackageSummary {
    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoopCommand) {
        return "Unknown"
    }

    try {
        $packageCount = @(& $scoopCommand.Source list 2>$null | Select-Object -Skip 1).Count
        return "$packageCount (scoop)"
    }
    catch {
        return "Unknown"
    }
}

function Show-CareFetch {
    $accent = Get-AccentColor -ForceColor:$ForceColor
    $reset = if ($accent) { "$([char]27)[0m" } else { "" }

    $username = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    $os = Get-CimInstanceSafe -ClassName "Win32_OperatingSystem"
    $computerSystem = Get-CimInstanceSafe -ClassName "Win32_ComputerSystem"
    $baseBoard = Get-CimInstanceSafe -ClassName "Win32_BaseBoard"
    $cpuInfo = Get-CimInstanceSafe -ClassName "Win32_Processor" | Select-Object -First 1
    $gpuInfo = Get-CimInstanceSafe -ClassName "Win32_VideoController" | Select-Object -First 1
    $disk = Get-DiskUsage

    $osCaption = if ($os.Caption) { $os.Caption } else { "Unknown" }
    $osBuild = Get-OSVersionDisplay
    $kernel = if ($os.Version) { $os.Version } else { "Unknown" }
    $hostModel = if ($computerSystem.Model) { $computerSystem.Model } else { "Unknown" }
    $motherboard = if ($baseBoard.Product) { $baseBoard.Product } else { "Unknown" }
    $uptime = Get-Uptime
    $shell = "PowerShell v$($PSVersionTable.PSVersion)"
    $terminal = Get-TerminalName
    $cpu = if ($cpuInfo.Name) { $cpuInfo.Name.Trim() } else { "Unknown" }
    $gpu = if ($gpuInfo.Name) { $gpuInfo.Name } else { "Unknown" }
    $resolution = Get-Resolution
    $memory = Get-MemoryUsage
    $packages = Get-PackageSummary

    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  $username@$hostname"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  -----------"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  OS: $osCaption [$osBuild - 64-Bit]"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Host: $hostModel"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Kernel: $kernel"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Motherboard: $motherboard"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Uptime: $uptime"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Packages: $packages"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Shell: $shell"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Resolution: $resolution"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Terminal: $terminal"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  CPU: $cpu"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  GPU: $gpu"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Memory: $memory"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Disk ($($disk.Label)): $($disk.Usage)"
    Write-Host ""
}

Show-CareFetch
