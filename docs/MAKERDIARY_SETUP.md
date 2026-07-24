# Makerdiary MDK USB Dongle setup

This guide is for the Makerdiary nRF52840 MDK USB Dongle. It is written for
people who only want to install OpenPuck; no development experience is
required.

You do not normally need a debugger, soldering, Arduino CLI, or SWD
programming. There are two jobs:

1. Run a one-time conversion from the factory S132 system software to S140.
2. Copy the Makerdiary OpenPuck UF2 onto the dongle.

Future OpenPuck updates only require the second job.

## Before you start

You need:

- the Makerdiary nRF52840 MDK USB Dongle;
- a Windows, macOS, or Linux computer;
- Python 3;
- the two Makerdiary files described below.

### 1. Install Python 3

First check whether Python is already installed.

macOS or Linux:

```bash
python3 --version
```

Windows PowerShell:

```powershell
py --version
```

If that prints a Python 3 version, continue to the next section.

- **Windows:** install Python 3 from
  [python.org](https://www.python.org/downloads/windows/). Select **Add Python
  to PATH** during installation.
- **macOS:** install Python 3 from
  [python.org](https://www.python.org/downloads/macos/) if it is not already
  available.
- **Linux:** install Python 3 and its virtual-environment package through your
  distribution. On Ubuntu or Debian:

  ```bash
  sudo apt install python3 python3-venv
  ```

### 2. Make a download folder

Create a folder named `OpenPuck-Makerdiary` inside your Downloads folder. This
keeps the firmware and the one-time conversion tool together.

Then open Terminal (macOS/Linux) or PowerShell (Windows) and move into it.

macOS or Linux:

```bash
mkdir -p ~/Downloads/OpenPuck-Makerdiary
cd ~/Downloads/OpenPuck-Makerdiary
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\Downloads\OpenPuck-Makerdiary"
Set-Location "$HOME\Downloads\OpenPuck-Makerdiary"
```

Keep this window open for the remaining steps.

### 3. Download the two files

Open the
[latest Makerdiary release](https://github.com/stickman-dev/openpuck/releases/latest)
and download these two assets into the folder you just created:

```text
makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip
OpenPuck-<release-version>-makerdiary-mdk.uf2
```

For example, release `0.9.31-mdk3` provides:

```text
OpenPuck-0.9.31-mdk3-makerdiary-mdk.uf2
```

The first `mdk3` is part of the release version and changes with newer
Makerdiary releases. The final `makerdiary-mdk` identifies the board and stays
the same. Always choose the newest UF2 whose full name ends in
`-makerdiary-mdk.uf2`.

If your browser saves them directly into `Downloads`, move both files into
`Downloads/OpenPuck-Makerdiary` before continuing. When asked where to save a
file, you can instead select that folder immediately.

Do **not** extract the ZIP file. The conversion tool needs the ZIP itself.

Do not use an OpenPuck file labelled `standard`, `factory-reset`, or
`promicro` on this dongle.

### 4. Install the one-time conversion tool

The following commands create an isolated Python environment inside the
download folder and install `adafruit-nrfutil`. They do not change the rest of
your Python installation.

macOS or Linux:

```bash
python3 -m venv openpuck-tools
source openpuck-tools/bin/activate
python -m pip install adafruit-nrfutil
```

Windows PowerShell:

```powershell
py -m venv openpuck-tools
.\openpuck-tools\Scripts\Activate.ps1
python -m pip install adafruit-nrfutil
```

When the environment is active, the start of the command prompt normally
shows `(openpuck-tools)`.

If PowerShell says that running scripts is disabled, run this once in the same
window and then repeat the activation command:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## One-time S132 to S140 conversion

### 1. Put the dongle into bootloader mode

The factory dongle does not yet support double-click reset:

1. Unplug the dongle.
2. Press and hold its button.
3. Plug it into the computer while continuing to hold the button.
4. Release the button when the RGB LED turns green.

A drive named `UF2BOOT` should appear.

After the conversion, the modified bootloader enables double-click reset for
future UF2 updates.

Open `INFO_UF2.TXT` on that drive. If it already says
`SoftDevice: S140 6.1.1`, the one-time conversion has already been completed;
skip directly to [Install OpenPuck](#install-openpuck).

The dongle also creates a serial port. The next step identifies its name.

### 2. Find the serial port

macOS:

```bash
ls /dev/cu.usbmodem*
```

The result resembles `/dev/cu.usbmodem1101`.

Linux:

```bash
ls /dev/ttyACM*
```

The result is normally `/dev/ttyACM0`.

Windows:

1. Right-click the Start button and open **Device Manager**.
2. Expand **Ports (COM & LPT)**.
3. Find the new USB serial device and note its port, such as `COM5`.

If several ports are listed, unplug the dongle and check the list. Then hold
its button while plugging it back in and check again. The port that appears is
the one to use. Re-entering bootloader mode can change the port number, so
always use the current value.

### 3. Run the conversion

Use the command for your system, replacing the example port with the one found
above.

macOS:

```bash
adafruit-nrfutil --verbose dfu serial \
  --package makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip \
  -p /dev/cu.usbmodem1101 -b 115200
```

Linux:

```bash
adafruit-nrfutil --verbose dfu serial \
  --package makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip \
  -p /dev/ttyACM0 -b 115200
```

Windows PowerShell:

```powershell
adafruit-nrfutil --verbose dfu serial `
  --package makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip `
  -p COM5 -b 115200
```

Do not unplug the dongle while the transfer is running. It normally takes
about 20 seconds and finishes with:

```text
Device programmed.
```

The new bootloader configures the Makerdiary V1.1 reset circuit and
automatically resets once. This one extra first reset is expected.

### 4. Check the conversion

If `UF2BOOT` is not mounted, double-click the dongle button again. Open
`INFO_UF2.TXT` on that drive and confirm it contains:

```text
UF2 Bootloader 0.7.1-openpuck1
SoftDevice: S140 6.1.1
```

The conversion only needs to be performed once.

## Install OpenPuck

1. If `UF2BOOT` is not already mounted, double-click the dongle button.
2. Drag the downloaded `OpenPuck-<release-version>-makerdiary-mdk.uf2` file onto
   `UF2BOOT`.
3. Wait for the red programming blink to finish.
4. Unplug and reconnect the dongle.
5. Open the
   [OpenPuck WebAdmin page](https://safijari.github.io/openpuck/) in Chrome or
   Edge and confirm it connects.

Changing controller mode should now produce a quick `pin/replug` reset rather
than a `watchdog (hang)` reset.

## Future OpenPuck updates

For later releases:

1. Download the new file whose name ends in `-makerdiary-mdk.uf2`.
2. Double-click the dongle button to mount `UF2BOOT`.
3. Drag the new UF2 onto the drive.
4. Wait for programming to finish, then unplug and reconnect.

You do not need to repeat the S132-to-S140 conversion.

The WebAdmin panel correctly reports **manual UF2 only** for this board. Do not
use its firmware-update feature with the Makerdiary dongle.

## Troubleshooting

### The serial port does not appear

- Confirm the RGB LED is green and `UF2BOOT` is mounted.
- Unplug the factory dongle, then hold its button while plugging it back in.
- Try another USB port. Avoid an unpowered USB hub while converting.
- On Windows, close any program that may already have the COM port open.

### The conversion tool cannot open the port

- Check the port again; its name or number may have changed.
- Make sure `(openpuck-tools)` appears at the start of the command prompt.
- Close Device Manager's port properties window and any serial-terminal
  software, then try again.
- On Linux, a `Permission denied` error may mean your user needs serial-port
  access. Add it to the `dialout` group with
  `sudo usermod -a -G dialout "$USER"`, then sign out and back in.

### The conversion was interrupted

Unplug the dongle, hold its button while plugging it back in, and confirm
`UF2BOOT` and the serial port return. Then run the same conversion command
again.

### The bootloader no longer appears

If no `UF2BOOT` drive or serial port appears on any USB port, use the
[advanced SWD recovery procedure](#advanced-swd-installation-and-recovery).

## Advanced: SWD installation and recovery

SWD is not required for a normal installation. It is useful if the serial
conversion cannot run, the bootloader is damaged, or you prefer to program a
complete image directly.

You need a CMSIS-DAP-compatible SWD probe, such as a Raspberry Pi Debug Probe,
and access to the dongle's `DIO`, `CLK`, and `GND` pads.

### 1. Connect the probe

```text
Probe SWDIO -> dongle DIO
Probe SWCLK -> dongle CLK
Probe GND   -> dongle GND
```

Power the dongle from USB. With a Raspberry Pi Debug Probe, use its **DEBUG**
connector, not its UART connector.

### 2. Install pyOCD

macOS or Linux:

```bash
python3 -m venv makerdiary-swd-tools
source makerdiary-swd-tools/bin/activate
python -m pip install pyocd
pyocd list
```

Windows PowerShell:

```powershell
py -m venv makerdiary-swd-tools
.\makerdiary-swd-tools\Scripts\Activate.ps1
python -m pip install pyocd
pyocd list
```

### 3. Program the recovery image

Download the release asset named:

```text
makerdiary-s140-6.1.1-bootloader-0.7.1-openpuck1-swd.hex
```

Run:

```bash
pyocd load -t nrf52840 -M halt -e sector \
  makerdiary-s140-6.1.1-bootloader-0.7.1-openpuck1-swd.hex
```

The combined image includes S140 and the modified bootloader. On its first
boot, the bootloader configures P0.18 as the reset pin and automatically resets
once. Do not convert the image to UF2 or copy it to `UF2BOOT`.

When programming finishes, disconnect the probe, unplug and reconnect the
dongle, and double-click its button. `INFO_UF2.TXT` should report:

```text
UF2 Bootloader 0.7.1-openpuck1
SoftDevice: S140 6.1.1
```

You can then continue with [Install OpenPuck](#install-openpuck).

Makerdiary's
[DAPLink guide](https://wiki.makerdiary.com/nrf52840-mdk-usb-dongle/programming/daplink/)
has additional probe and wiring information.

## Building from source (developers)

From the repository root:

```bash
make build-makerdiary
```

This produces:

```text
build/makerdiary/OpenPuck.ino.hex
build/makerdiary/OpenPuck-makerdiary-mdk.uf2
```

The target uses the repo-local Makerdiary pin and crystal configuration, links
the application at `0x26000` for S140 6.1.1, and checks that no application
data overlaps the resident bootloader at `0xF4000`.

The pinned bootloader source, patch, packaging procedure, decision test, and
hardware-validation record are in
[`bootloader/makerdiary`](../bootloader/makerdiary/).

The complete factory-S132 conversion, automatic reset-pin configuration,
OpenPuck installation, mode switching, and double-click bootloader entry have
all been tested on Makerdiary V1.1 hardware.
