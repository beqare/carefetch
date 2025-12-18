# carefetch.ps1
param(
    [switch]$ForceColor = $false
)

function Get-AccentColor {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\DWM"
        $accentColor = Get-ItemProperty -Path $regPath -Name "AccentColor" -ErrorAction Stop
        $colorValue = $accentColor.AccentColor
        # Convert to RGB
        $b = ($colorValue -band 0xFF)
        $g = (($colorValue -shr 8) -band 0xFF)
        $r = (($colorValue -shr 16) -band 0xFF)
        return "$([char]27)[38;2;$r;$g;${b}m"
    }
    catch {
        return "$([char]27)[96m"  # Fallback: hellcyan
    }
}

function Get-Uptime {
    $os = Get-WmiObject Win32_OperatingSystem
    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($bootTime)
    $days = $uptime.Days
    $hours = $uptime.Hours
    $minutes = $uptime.Minutes
    return "$days days $hours hours $minutes minutes"
}

function Get-DiskUsage {
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $sizeGB = [math]::Round($drive.Size / 1GB, 2)
    $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $usedGB = $sizeGB - $freeGB
    return "$usedGB GiB / $sizeGB GiB ($([math]::Round(($usedGB / $sizeGB) * 100))%)"
}

function Get-MemoryUsage {
    $os = Get-WmiObject Win32_OperatingSystem
    $totalMem = [math]::Round([int64]$os.TotalVisibleMemorySize * 1KB / 1GB, 2)
    $freeMem = [math]::Round([int64]$os.FreePhysicalMemory * 1KB / 1GB, 2)
    $usedMem = $totalMem - $freeMem
    $percent = [math]::Round(($usedMem / $totalMem) * 100)
    return "$usedMem GiB / $totalMem GiB ($percent%)"
}

function Get-Resolution {
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $resolutions = $screens | ForEach-Object { "$($_.Bounds.Width)x$($_.Bounds.Height)" }
    return ($resolutions -join ", ")
}

function Show-CareFetch {
    $accent = Get-AccentColor
    $reset = "$([char]27)[0m"

    $username = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    $osCaption = (Get-WmiObject -class Win32_OperatingSystem).Caption
    $osBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
    $kernel = (Get-WmiObject Win32_OperatingSystem).Version
    $hostModel = (Get-WmiObject -Class Win32_ComputerSystem).Model
    $motherboard = (Get-WmiObject -Class Win32_BaseBoard).Product
    $uptime = Get-Uptime
    $shell = "PowerShell v$($PSVersionTable.PSVersion)"
    $terminal = "Windows Console"
    $cpu = (Get-WmiObject -Class Win32_Processor).Name.Trim()
    $gpu = (Get-WmiObject -Class Win32_VideoController | Select-Object -First 1).Name
    $resolution = Get-Resolution
    $memory = Get-MemoryUsage
    $disk = Get-DiskUsage

    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  $username@$hostname"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  -----------"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  OS: $osCaption [$osBuild - 64-Bit]"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Host: $hostModel"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Kernel: $kernel"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Motherboard: $motherboard"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Uptime: $uptime"
    Write-Host "                                    Packages: 1 (scoop)"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Shell: $shell"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Resolution: $resolution"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Terminal: $terminal"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  CPU: $cpu"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  GPU: $gpu"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Memory: $memory"
    Write-Host "${accent} lllllllllllllll   lllllllllllllll${reset}  Disk (C:): $disk"
    Write-Host ""
}

Show-CareFetch