## CareFetch

CareFetch is a small, Windows-focused system information fetcher written in PowerShell. It prints concise system and hardware information with optional ANSI color theming (it uses the Windows accent color when available).

## Features

- Compact, human-readable output for quick system overviews
- Displays OS, build, kernel, uptime, host model and motherboard
- Shows CPU, GPU, display resolution, memory and disk usage
- Uses Windows accent color (when available) for nicer output
- Single-file script with an optional simple installer

## Prerequisites

- Windows 10 / 11
- PowerShell 7+ is recommended for best ANSI color and cross-shell behavior. Built-in Windows PowerShell may work but experience can vary.
- A terminal that supports ANSI colors (Windows Terminal, Windows Console with ANSI support, or PowerShell 7+)

## Installation

Quick install (run in an elevated or regular PowerShell session):

```powershell
iwr -useb https://raw.githubusercontent.com/beqare/carefetch/main/install.ps1 | iex
```

Manual: download `carefetch.ps1` and place it somewhere in your PATH or run it directly:

```powershell
pwsh .\carefetch.ps1
# or
powershell -File .\carefetch.ps1
```

## Usage

Run the script directly to print system information:

```powershell
.\carefetch.ps1
```

The script accepts a `-ForceColor` switch to force ANSI color output regardless of auto-detection:

```powershell
.\carefetch.ps1 -ForceColor
```

You can also use the one-line installer pattern to fetch and run in a single command:

```powershell
iwr -useb https://raw.githubusercontent.com/beqare/carefetch/main/carefetch.ps1 | iex
```

## What the script shows

- Username and hostname
- OS name and display version/build
- Kernel version
- Host model and motherboard
- Uptime
- Shell & terminal summary
- CPU and GPU
- Display resolutions
- Memory and disk usage (C:)

## Troubleshooting

- If colors look wrong, try running the script in PowerShell 7 or Windows Terminal.
- If a value is missing (for example GPU or motherboard), ensure your account has permission to query WMI and that the system exposes the information.

## Contributing

Bug reports, small fixes and improvements are welcome. Open an issue or send a pull request with a focused change.

## License

This project is provided "as-is". Add a license file if you want a specific license.
# CareFetch

A lightweight PowerShell system information fetch tool for Windows.

## Features

- Displays key system information with colorful output
- Shows Windows version, hardware specs, and resource usage
- Uses Windows accent color for dynamic theming
- Supports both PowerShell and Command Prompt
- Easy one-line installation

## Installation

Run this command in PowerShell as **User** or **Administrator**:

```powershell
iwr -useb https://raw.githubusercontent.com/beqare/carefetch/refs/heads/main/install.ps1 | iex
```
