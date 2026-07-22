<#
.SYNOPSIS
    Find a Raspberry Pi Pico and attach it to WSL2 via usbipd.
.DESCRIPTION
    Locates the USB device with the Raspberry Pi vendor id (2e8a), binds it if
    it isn't shared yet (requires Administrator the first time), and attaches it
    to the given WSL distro.
.PARAMETER Distro
    WSL distro to attach to. Defaults to 'picow'.
.EXAMPLE
    .\attach-pico.ps1
    .\attach-pico.ps1 -Distro Ubuntu
#>
param(
    [string]$Distro = "picow"
)

$ErrorActionPreference = "Stop"

# Parse `usbipd list` for a line whose VID:PID starts with 2e8a.
$line = usbipd list | Select-String '2e8a:' | Select-Object -First 1
if (-not $line) {
    Write-Error "No Raspberry Pi Pico (VID 2e8a) found. Check the cable/connection and run 'usbipd list'."
    exit 1
}

# BUSID is the first whitespace-delimited token on the line.
$busid = ($line.ToString().Trim() -split '\s+')[0]
# Order matters: 'Not shared' also contains 'shared', so test it before 'Shared'.
$state = if     ($line.ToString() -match 'Attached')   { 'attached' }
         elseif ($line.ToString() -match 'Not shared') { 'not shared' }
         else                                          { 'shared' }

Write-Host "Found Pico at busid $busid (state: $state)"

if ($state -eq 'attached') {
    Write-Host "Already attached — nothing to do."
    exit 0
}

if ($state -eq 'not shared') {
    Write-Host "Binding $busid (needs Administrator)..."
    usbipd bind --busid $busid
}

# usbipd 5.3.0+: the distro is the value of --wsl (no --distribution flag).
Write-Host "Attaching $busid to WSL distro '$Distro'..."
usbipd attach --busid $busid --wsl $Distro

Write-Host "Done. Inside WSL, verify with: picotool info   (or: lsusb | grep 2e8a)"
