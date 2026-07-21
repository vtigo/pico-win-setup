# pico-win-setup

Everything needed to access a **Raspberry Pi Pico / Pico W** from **WSL2** on a
Windows machine, using [usbipd-win](https://github.com/dorssel/usbipd-win) to
forward the USB device into Linux. Reproducible on any Windows PC.

The Pico's USB connects to Windows; `usbipd` attaches it to a WSL2 distro; you
then flash firmware (`.uf2`) or talk to it over serial from inside Linux.

---

## Prerequisites (one-time per machine)

1. **WSL2** with a Linux distro installed.
   ```powershell
   wsl --install
   ```
   The distro name used in the examples below is `picow`. Substitute your own
   (see `wsl -l -v`).

2. **usbipd-win** on Windows:
   ```powershell
   winget install usbipd
   ```
   Open a new terminal afterwards so `usbipd` is on PATH.

3. **USB/IP tools inside the distro** (needed so WSL can accept the device):
   ```bash
   sudo apt update
   sudo apt install -y linux-tools-generic hwdata usbutils
   ```
   > Recent WSL kernels already include USB/IP support; if `usbipd attach` works
   > you can skip this.

---

## Identify the Pico

Plug the Pico into a USB port. Hold the **BOOTSEL** button while plugging in if
you want to flash firmware (it then enumerates as a mass-storage "RP2 Boot"
device with VID:PID `2e8a:0003`).

```powershell
usbipd list
```

Look for the Raspberry Pi vendor id **`2e8a`**. Example:

```
BUSID  VID:PID    DEVICE                              STATE
1-6    2e8a:0003  USB Mass Storage Device, RP2 Boot   Not shared
```

Common Pico VID:PIDs:

| VID:PID     | Meaning                                    |
|-------------|--------------------------------------------|
| `2e8a:0003` | BOOTSEL / bootloader — mass storage (flash)|
| `2e8a:0005` | MicroPython (serial + REPL)                |
| `2e8a:000a` | Pico SDK USB serial (CDC)                  |

The `BUSID` (e.g. `1-6`) can change between plug-ins — always re-check.

---

## Share the device with WSL

### First time only: bind (requires an **Administrator** terminal)

```powershell
usbipd bind --busid 1-6
```
Binding is persistent across reboots — do it once per device.

### Every time you plug in: attach

```powershell
usbipd attach --wsl --busid 1-6
```

Or use the helper in this repo, which finds the Pico automatically:

```powershell
.\scripts\attach-pico.ps1            # binds if needed, then attaches to WSL
.\scripts\attach-pico.ps1 -Distro picow
```

To detach:
```powershell
usbipd detach --busid 1-6
```

---

## Use it from WSL

Check what showed up inside the distro:

```bash
lsusb | grep -i 2e8a          # should list the Raspberry Pi device
lsblk -o NAME,MODEL           # RP2 mass-storage drive (BOOTSEL mode)
ls /dev/ttyACM*               # serial port (firmware running)
```

### A) Flash firmware (BOOTSEL mode)

The Pico appears as a FAT drive; copying a `.uf2` onto it flashes and reboots
the board. Use the helper script (auto-detects the RP2 drive):

```bash
scripts/flashpico firmware.uf2
```

Install it onto your PATH so you can call it from anywhere:

```bash
mkdir -p ~/bin && cp scripts/flashpico ~/bin/ && chmod +x ~/bin/flashpico
# add ~/bin to PATH if it isn't already:
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
```

Manual equivalent:
```bash
sudo mkdir -p /mnt/pico
sudo mount /dev/sdX1 /mnt/pico     # the RP2 partition from lsblk
sudo cp firmware.uf2 /mnt/pico/
sync
```
The board reboots itself when the copy finishes; the drive disappearing is
normal, not an error.

Need MicroPython? Download `RPI_PICO_W-*.uf2` from
<https://micropython.org/download/RPI_PICO_W/> and flash that.

### B) Serial / REPL (firmware already running)

Only works when firmware is running (not in BOOTSEL mode). After flashing
MicroPython, the board re-enumerates — re-run `usbipd attach` (busid may change),
then:

```bash
sudo screen /dev/ttyACM0 115200          # raw serial
# or, for MicroPython:
pip install mpremote
mpremote connect /dev/ttyACM0 repl
```

---

## Quick cheat sheet

```
# Windows
usbipd list
usbipd bind   --busid <ID>     # once, as Administrator
usbipd attach --wsl --busid <ID>
usbipd detach --busid <ID>

# WSL
flashpico firmware.uf2         # BOOTSEL: flash a .uf2
mpremote connect /dev/ttyACM0 repl   # running firmware: REPL
```

---

## Troubleshooting

- **Pico not in `usbipd list`** — usually a power-only USB cable, or not seated.
  Try a known-good data cable and a direct port (not a hub).
- **`Access denied` on bind** — the terminal isn't elevated. Use an
  Administrator PowerShell.
- **Attaches but nothing in WSL** — install the USB/IP tools in the distro (see
  Prerequisites), and confirm you targeted the right distro.
- **Device name changes (`sde` → `sdf`)** — expected; `flashpico` and the
  helper detect the device instead of hardcoding it.
- **`umount: target is busy`** — you have a shell `cd`'d into `/mnt/pico`, or the
  Pico already rebooted and dropped the mount. Both are harmless.
