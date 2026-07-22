<#
.SYNOPSIS
    Find a Raspberry Pi Pico and attach it to WSL2 via usbipd.
.DESCRIPTION
    Locates the USB device with the Raspberry Pi vendor id (2e8a), binds it if
    it isn't shared yet (requires Administrator the first time), and attaches it
    to a WSL distro. The distro defaults to "Ubuntu"; override it with -d or
    --distro.
.EXAMPLE
    .\attach-pico.ps1
    .\attach-pico.ps1 -d Ubuntu-24.04
    .\attach-pico.ps1 --distro Ubuntu-24.04
#>

$ErrorActionPreference = "Stop"

# --- parse args: -d / --distro <name>, -h / --help --------------------------
$Distro = "Ubuntu"
for ($i = 0; $i -lt $args.Count; $i++) {
    switch -Regex ($args[$i]) {
        '^(-d|--distro|-distro)$' {
            if ($i + 1 -ge $args.Count) {
                Write-Error "Missing value for $($args[$i])"; exit 2
            }
            $Distro = $args[++$i]
        }
        '^(-h|--help)$' {
            Write-Host "usage: attach-pico.ps1 [-d|--distro <name>]   (default: Ubuntu)"
            exit 0
        }
        default {
            Write-Error "Unknown argument: $($args[$i])  (try --help)"; exit 2
        }
    }
}

# --- find the Pico ----------------------------------------------------------
# Parse `usbipd list` for a line whose VID:PID starts with 2e8a.
$line = usbipd list | Select-String '2e8a:' | Select-Object -First 1
if (-not $line) {
    Write-Error "No Raspberry Pi Pico (VID 2e8a) found. Check the cable/connection and run 'usbipd list'."
    exit 1
}

# BUSID is the first whitespace-delimited token on the line.
$busid = ($line.ToString().Trim() -split '\s+')[0]
$state = if ($line.ToString() -match 'Shared')      { 'shared' }
         elseif ($line.ToString() -match 'Attached') { 'attached' }
         else                                        { 'not shared' }

Write-Host "Found Pico at busid $busid (state: $state)"

# --- bind (once) + attach ---------------------------------------------------
if ($state -eq 'not shared') {
    Write-Host "Binding $busid (needs Administrator)..."
    usbipd bind --busid $busid
}

Write-Host "Attaching $busid to WSL distro '$Distro'..."
usbipd attach --busid $busid --wsl $Distro

Write-Host "Done. Inside WSL, check with: lsusb | grep 2e8a   or   picotool info"
