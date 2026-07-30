# Makerdiary nRF52840 Connect Kit setup

This guide is for the Makerdiary nRF52840 Connect Kit (U.FL / external-antenna
variant). It is a different board from the
[Makerdiary MDK USB Dongle](./MAKERDIARY_SETUP.md) — do not mix up their UF2
files or setup guides.

## Why this board needs its own build

Every other board in this repo (Pro Micro, the MDK USB Dongle, mdbt50q-cx)
runs an Adafruit-style bootloader with a real S140 6.1.1 SoftDevice, and the
application is linked to start at `0x26000` to match it.

The Connect Kit ships from the factory with a **different** SoftDevice: S132
5.1.0. You can confirm this yourself by opening `INFO_UF2.TXT` on its
`UF2BOOT` drive — it should read something close to:

```text
UF2 Bootloader 0.7.0-rtm ...
Model: Makerdiary nRF52840 Connect Kit
Board-ID: nRF52840-Connect-Kit
SoftDevice: S132 5.1.0
```

S132 5.1.0 reserves flash up through `0x23000`, not `0x26000` — Nordic's own
resource-requirements guidance for that SoftDevice version puts the
application start address there. A standard-layout OpenPuck UF2 (linked for
`0x26000`) will write to the drive successfully (you'll see the red
programming blink) but never boot: the bootloader's non-DFU boot path reads
the *installed* SoftDevice's declared size back to compute where to jump, and
finds nothing valid at that address. That mismatch — not a bad UF2 write — is
almost certainly why a stock UF2 "installs" but nothing ever enumerates over
USB.

**This port does not replace the bootloader or the SoftDevice.** The MDK USB
Dongle port fixed its equivalent problem by installing a new bootloader +
SoftDevice over serial DFU, using a board definition pinned to a known
Adafruit_nRF52_Bootloader commit. That path isn't available here with the same
confidence: Makerdiary's own bootloader fork
([github.com/makerdiary/uf2-bootloader](https://github.com/makerdiary/uf2-bootloader))
has no published board definition for the Connect Kit to safely rebuild
against, and there was no SWD probe on hand to recover the board if a
from-scratch board definition had a bug. Instead, OpenPuck is linked to start
exactly where the factory SoftDevice already ends (`0x23000`) and is installed
over the existing `UF2BOOT` drive, completely untouched otherwise. Nothing
about the bootloader or SoftDevice is ever written.

## Before you start

You need:

- the Makerdiary nRF52840 Connect Kit;
- a computer that can mount a USB mass-storage drive.

No Python, no conversion tool, no serial DFU, no SWD probe.

## Install OpenPuck

1. Open the
   [latest release](https://github.com/stickman-dev/openpuck/releases/latest)
   and download the asset whose name ends in `-makerdiary-connectkit.uf2`.
   Do not use a file labelled `standard`, `factory-reset`, `promicro`, or
   `makerdiary-mdk` on this board.
2. Put the board into bootloader mode: double-tap the RESET button (SW2, the
   button next to the USB-C port). A drive named `UF2BOOT` should appear.
   - If double-tap doesn't work (e.g. the board is stuck from a previous
     mismatched flash), unplug it, hold RESET while plugging it back in, and
     release once the drive appears.
3. Drag the downloaded `.uf2` file onto `UF2BOOT`.
4. Wait for the programming blink to finish, then unplug and reconnect.
5. Open the [OpenPuck WebAdmin page](https://safijari.github.io/openpuck/) in
   Chrome or Edge and confirm it connects.

## Future OpenPuck updates

Same as above: download the newest release asset ending in
`-makerdiary-connectkit.uf2`, double-tap RESET, drag it onto `UF2BOOT`. There
is no one-time provisioning step to repeat.

The WebAdmin panel's in-app firmware-update feature is **disabled** on this
build (`OPK_WEBUSB_FW_UPDATE=0`) — its staged-update logic assumes the
standard `0x26000` layout, which doesn't apply here. Always update through the
`UF2BOOT` drive.

## Troubleshooting

### The UF2 drive doesn't appear

- Double-tap RESET (SW2) more deliberately — the window between taps matters.
- Unplug the board, hold RESET while plugging it back in, release once
  `UF2BOOT` mounts.
- Try another USB cable/port; avoid an unpowered hub.

### The UF2 "installs" but nothing enumerates afterward

This is the exact symptom this build exists to fix. Confirm you flashed the
file ending in `-makerdiary-connectkit.uf2` and not `standard`,
`factory-reset`, or `makerdiary-mdk`. If you're building from source yourself,
confirm the output came from `make build-makerdiary-connectkit`, not `make
build`.

### Nothing works and the board won't reboot into `UF2BOOT` at all

This build never writes to the bootloader or SoftDevice regions, so RESET
should always be able to get you back to `UF2BOOT` regardless of what
application image is installed. If that stops being true, please open an
issue with exactly what you flashed and in what order — that would mean
something in this analysis was wrong and needs correcting.

## Building from source (developers)

From the repository root:

```bash
make build-makerdiary-connectkit
```

This produces:

```text
build/connectkit/OpenPuck.ino.hex
build/connectkit/OpenPuck-makerdiary-connectkit.uf2
```

The target uses the repo-local Connect Kit pin/clock configuration
(`variants/makerdiary_nrf52840_connectkit/`) and a repo-local linker script
(`variants/makerdiary_nrf52840_connectkit/linker/nrf52840_connectkit_s132_v5.ld`)
that links the application at `0x23000` instead of the standard `0x26000`,
then checks that no application data falls outside `[0x23000, 0xED000)` —
i.e. it never touches the SoftDevice below it or the bootloader/LittleFS
region at `0xED000` and above.

## What's verified vs. inferred — read this before relying on this port

This port compiles, produces a UF2 whose data lands exactly in the intended
`0x23000`–`0xED000` window, and — confirmed on real Connect Kit hardware —
boots and enumerates correctly:

```text
Bus 001 Device 025: ID 28de:1304 Valve Software Steam Controller Puck
```

That confirms the core fix (linking at `0x23000` instead of `0x26000`) is
correct: the bootloader accepts a UF2 write there and jumps to it
successfully. The rest of the device's behavior (LED color, controller
pairing, mode switching) is still being worked through — see the checklist
below. Details:

**Verified directly** (from Makerdiary's own schematic PDF and this unit's
`INFO_UF2.TXT`, not inferred):
- A 32.768 kHz crystal (Y2) is populated for LFCLK — the variant forces LFXO
  selection on boot, same as the MDK port.
- RESET (P0.18) is a plain pushbutton to GND with no spare GPIO wired to it —
  there is no equivalent of the MDK's P0.16 hardware self-reset trick
  available on this board.
- The factory SoftDevice is S132 5.1.0, and S132 5.1.0's application start
  address is `0x23000` per Nordic's own published resource requirements for
  that SoftDevice version.
- LED/button pin assignments (RGB LED on P1.10/11/12, green LED on P1.15, USR
  button on P1.00, QSPI on P0.17/19–23) match the schematic exactly.
- **UF2 write + boot at `0x23000`.** Confirmed: the board enumerates as
  `28de:1304 Valve Software Steam Controller Puck`, i.e. Steam/puck-mode USB
  presentation is working correctly out of boot.

**Confirmed on real hardware (this unit):**
- RGB LED shows steady blue at idle.
- The [WebUSB configurator](https://safijari.github.io/openpuck/) connects and
  loads settings.
- A real Steam Controller 2 pairs to it correctly.

**Inferred, not yet hardware-verified:**
- **Mode-switch reset.** `modeSwitchReboot()` uses the standard
  `NVIC_SystemReset()` path (no `OPK_SELF_RESET_PIN` defined), matching the
  Pro Micro and mdbt50q-cx, which don't need the MDK's watchdog workaround.
  It's possible the Connect Kit's bootloader has its own timing quirk that
  makes this behave differently — watch specifically for a mode switch that
  hangs or loops instead of cleanly re-enumerating. Untested against real
  hardware as of this writing (the reporting user only needed puck/Steam
  mode); if you rely on Xbox/Switch/PS4/PS5/DS4 emulation on this board,
  please verify and report back.
- **UICR `PSELRESET`.** The board's own devicetree source enables
  `gpio-as-nreset`, and it has a labeled physical RESET button, so P0.18 is
  almost certainly already configured as a real hardware reset pin at the
  factory — but this has not been read back via SWD/`nrfjprog` to confirm the
  literal register value.

## Checklist for you to verify on real hardware

Confirmed working in Steam/puck mode on real Connect Kit hardware:

1. ✅ RGB LED shows steady blue (idle) after flashing.
2. ✅ Enumerates as a USB device (`28de:1304 Valve Software Steam Controller
   Puck`).
3. ✅ The [WebUSB configurator](https://safijari.github.io/openpuck/) connects
   and loads settings.
4. ✅ A real Steam Controller 2 puck-pairs correctly.

Still open (only matters if you use the emulated-controller modes; the
reporting user only needed puck/Steam mode, so this hasn't been exercised):

5. Does the back-4 + A/B/X/Y mode-switch chord cleanly reboot into each USB
   personality (Xbox/Switch/PS4/PS5/DS4), without a hang or a repeated reset
   loop? This is the item most likely to need follow-up given the MDK board's
   very different reset story — please report what you see if you rely on
   these modes.
6. Does RESET (double-tap) still reliably return you to `UF2BOOT` after
   OpenPuck has been running?
