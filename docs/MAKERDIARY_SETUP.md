# Makerdiary MDK USB Dongle setup

This guide is for the Makerdiary nRF52840 MDK USB Dongle. You do not normally
need a debugger, soldering, or SWD programming.

There are two separate jobs:

1. Replace the factory S132 system software once.
2. Copy the Makerdiary OpenPuck UF2 onto the dongle.

Afterwards, normal OpenPuck updates only require the second job.

## Before you start

Download these two files from the latest Makerdiary release:

```text
makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip
OpenPuck-0.9.31-mdk3-makerdiary-mdk.uf2
```

Do not use an OpenPuck file labelled `standard`, `factory-reset`, or
`promicro` on this dongle.

You also need `adafruit-nrfutil` for the one-time conversion:

```bash
python3 -m venv openpuck-tools
source openpuck-tools/bin/activate
python -m pip install adafruit-nrfutil
```

On Windows, activate the environment with:

```powershell
openpuck-tools\Scripts\Activate.ps1
python -m pip install adafruit-nrfutil
```

## One-time S132 to S140 conversion

1. Double-click the dongle's button. Its bootloader serial port should appear.
2. Find the port:

   - macOS: `ls /dev/cu.usbmodem*`
   - Linux: `ls /dev/ttyACM*`
   - Windows: look under **Ports (COM & LPT)** in Device Manager

3. Run the command for your system, replacing the port if necessary.

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

4. Do not unplug the dongle while the transfer is running. It normally takes
   about 20 seconds.
5. The new bootloader configures the V1.1 reset circuit and automatically
   resets once. This extra first reset is expected.
6. A drive named `UF2BOOT` should mount. Open `INFO_UF2.TXT` and confirm it
   contains:

   ```text
   UF2 Bootloader 0.7.1-openpuck1
   SoftDevice: S140 6.1.1
   ```

The conversion only needs to be performed once.

## Install OpenPuck

1. If `UF2BOOT` is not already mounted, double-click the dongle button.
2. Drag `OpenPuck-0.9.31-mdk3-makerdiary-mdk.uf2` onto `UF2BOOT`.
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

The WebAdmin panel correctly reports **manual UF2 only** for this board. Do not
use its firmware-update feature with the Makerdiary dongle.

## If something goes wrong

- If the serial command cannot open the port, confirm the dongle is in
  bootloader mode and check whether its port number changed.
- If the transfer was interrupted, double-click the button and try again.
- If the bootloader no longer appears at all, recovery requires an SWD probe.
  Follow the
  [SWD installation and recovery instructions](./BUILD_AND_DEPLOY.md#swd-installation-and-recovery).

The complete factory-S132 conversion, automatic reset-pin configuration,
OpenPuck installation, mode switching, and double-click bootloader entry have
all been tested on Makerdiary V1.1 hardware.
