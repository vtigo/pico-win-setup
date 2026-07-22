# pico-win-setup

Everything needed to access a **Raspberry Pi Pico / Pico W** from **WSL2** on a
Windows machine, using [usbipd-win](https://github.com/dorssel/usbipd-win) to
forward the USB device into Linux, and [picotool](https://github.com/raspberrypi/picotool)
to flash and inspect it. Reproducible on any Windows PC.

The Pico's USB connects to Windows → `usbipd` attaches it to a WSL2 distro →
`picotool` flashes firmware (`.uf2`/`.elf`/`.bin`) or you talk to it over serial.

---

## Prerequisites (one-time per machine)

1. **WSL2** with a Linux distro installed.
   ```powershell
   wsl --install
   ```
   Examples below use `Ubuntu-24.04` as the distro name. Substitute your own if
   different (`wsl -l -v` lists them); the `attach-pico.ps1` helper takes a
   `-d`/`--distro` flag so you don't have to edit any commands.

2. **usbipd-win** on Windows (examples assume **v5.3.0+**):
   ```powershell
   winget install usbipd
   ```
   Open a new terminal afterwards so `usbipd` is on PATH.

3. **Tools inside the distro:**
   ```bash
   sudo apt update
   sudo apt install -y picotool usbutils
   ```
   > `usbutils` gives you `lsusb` for diagnostics. Recent WSL kernels already
   > include USB/IP support; if `usbipd attach` works you need nothing else.

4. **udev rule so picotool works without sudo** (optional but recommended):
   ```bash
   sudo cp /usr/lib/udev/rules.d/99-picotool.rules /etc/udev/rules.d/ 2>/dev/null
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
   Without this, prefix picotool commands with `sudo`.

---

## Identify the Pico

Plug the Pico into a USB port. Hold the **BOOTSEL** button while plugging in to
put it in bootloader mode (VID:PID `2e8a:0003`, "RP2 Boot").

```powershell
usbipd list
```

Look for the Raspberry Pi vendor id **`2e8a`**. Example:

```
BUSID  VID:PID    DEVICE                              STATE
1-6    2e8a:0003  USB Mass Storage Device, RP2 Boot   Not shared
```

Common Pico VID:PIDs:

| VID:PID     | Meaning                                     |
|-------------|---------------------------------------------|
| `2e8a:0003` | BOOTSEL / bootloader — ready to flash       |
| `2e8a:0005` | MicroPython (serial + REPL)                 |
| `2e8a:000a` | Pico SDK USB serial (CDC)                   |

> The `BUSID` (e.g. `1-6`) **can change** between plug-ins — always re-check.

---

## Share the device with WSL

### First time only: bind (requires an **Administrator** terminal)

```powershell
usbipd bind --busid 1-6
```
Binding is persistent across reboots — do it once per device. Afterwards the
device shows as `Shared` in `usbipd list`.

### Every time: attach (v5.3.0 syntax)

```powershell
usbipd attach --busid 1-6 --wsl Ubuntu-24.04
```
> On usbipd **5.3.0+** the distro is the value of `--wsl` (the old
> `--distribution` flag was removed). The device becomes available in all WSL2
> distros regardless; naming one just picks which to boot if none is running.

Or use the helper in this repo, which finds the Pico automatically and binds if
needed:

```powershell
.\scripts\attach-pico.ps1                      # auto-detect, bind if needed, attach (default: Ubuntu)
.\scripts\attach-pico.ps1 -d Ubuntu-24.04      # or: --distro Ubuntu-24.04
```

After attaching, `usbipd list` should show the Pico as **`Attached`**.

To detach:
```powershell
usbipd detach --busid 1-6
```

---

## Use it from WSL

Confirm the device arrived:

```bash
lsusb | grep -i 2e8a          # Raspberry Pi device present?
picotool info                 # board + firmware details (sudo if no udev rule)
```

### Flash firmware

picotool loads `.uf2`, `.elf`, or `.bin` directly over the USB PICOBOOT
interface — no mounting required. `-x` reboots into the program right after:

```bash
picotool load -x firmware.uf2      # flash and run
picotool load firmware.elf         # flash a build artifact, stay in BOOTSEL
```

Other handy commands:

```bash
picotool info -a                   # everything picotool knows about the board
picotool reboot -f -u              # force a RUNNING Pico back into BOOTSEL
picotool save firmware.bin         # dump current flash to a file
```

> `picotool reboot -u` can put a running board into BOOTSEL over USB — so you
> don't have to physically hold the button + replug every cycle.

Need MicroPython? Download `RPI_PICO_W-*.uf2` from
<https://micropython.org/download/RPI_PICO_W/> and `picotool load -x` it.

### Serial / REPL (firmware already running)

Only works when firmware is running (not in BOOTSEL mode). After flashing
MicroPython the board re-enumerates and **detaches from WSL** — re-run the
attach (busid may have changed), then:

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
usbipd bind   --busid <ID>        # once, as Administrator
usbipd attach --busid <ID> --wsl Ubuntu-24.04
usbipd detach --busid <ID>

# WSL
picotool info                     # verify it's visible
picotool load -x firmware.uf2     # flash and run
mpremote connect /dev/ttyACM0 repl  # running firmware: REPL
```

---

## Troubleshooting

- **`No accessible RP-series devices in BOOTSEL mode were found`** — almost
  always means **the device isn't attached to WSL right now**, even if it's
  still plugged into the PC. Attachments do **not** survive a detach, replug, or
  flash/reboot — you must re-attach every time. Check `usbipd list`: if the Pico
  reads `Shared` (not `Attached`), re-run `usbipd attach --busid <ID> --wsl Ubuntu-24.04`.
  Confirm from WSL with `lsusb | grep 2e8a`.
- **Pico not in `usbipd list` at all** — usually a power-only USB cable, or not
  seated. Try a known-good data cable and a direct port (not a hub).
- **`Access denied` on bind** — the terminal isn't elevated. Use an
  Administrator PowerShell.
- **picotool works with `sudo` but not without** — install the udev rule (see
  Prerequisites step 4).
- **`sudo picotool: command not found`** — sudo's `secure_path` excludes where
  picotool installed. Use `sudo "$(which picotool)" info` or the udev rule.
- **`Unrecognized command or argument '--distribution'`** — you're on usbipd
  5.3.0+; use `--wsl <distro>` instead.
