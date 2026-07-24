# Build And Deploy

These instructions cover firmware builds for macOS, Linux, and Windows, plus static hosting of the WebUSB app through GitHub Pages.

## 1. Prerequisites

Hardware:

- nRF52840 board supported by the Adafruit nRF52 Arduino core
- USB cable
- Steam Controller 2 controller

Software:

- `arduino-cli`
- Adafruit nRF52 Arduino core
- `adafruit-nrfutil` (Python package, for DFU packaging - see "Build the firmware")
- Chrome or Edge for the WebUSB app

## 2. Install Arduino CLI

### macOS

```bash
brew install arduino-cli
```

### Linux

Use your package manager if it ships a recent `arduino-cli`, or download the release archive from Arduino and place `arduino-cli` on `PATH`.

### Windows

Use [choco](https://chocolatey.org/) and do a `choco install arduino-cli`. If you don't have that then install the official [Arduino CLI zip or MSI](https://arduino.github.io/arduino-cli/1.5/installation/), then ensure `arduino-cli.exe` is on `PATH`.

## 3. Install the board core

Run once on any platform:

```bash
pip install adafruit-nrfutil         # DFU packaging helper (required by the Adafruit nRF52 build recipe)
arduino-cli config init
arduino-cli core update-index
arduino-cli core install adafruit:nrf52 --additional-urls https://adafruit.github.io/arduino-board-index/package_adafruit_index.json
```

## 4. Build the firmware

From the repository root:

```bash
make build
```

That's the whole command — the USB flags the firmware needs are baked in, so you don't pass them yourself:

- `CFG_TUD_HID=6` — Steam mode exposes four HID interfaces (the Adafruit nRF core defaults to 2); one extra for mouse and one for WebUSB brings the total to 6.
- `CFG_TUD_TASK_QUEUE_SZ=512` — a deeper TinyUSB device event queue; the default of 16 can deadlock the firmware's loop under heavy USB traffic and trip the watchdog.
- `CFG_TUD_VENDOR_TX_BUFSIZE=256` — the WebUSB status blob (~118 B) must fit the vendor TX FIFO in one write; the default 64 is too small and the panel (which drops frames rather than block the loop) would send nothing — a blank dashboard.

**Overriding the defaults** (only if you need to) — pass them as `make` variables:

```bash
make build CFG_TUD_HID=6 CFG_TUD_TASK_QUEUE_SZ=128   # different interface count / queue depth
make build EXTRA_FLAGS="-DOPK_LOG=1"                  # add your own defines
make build FQBN=adafruit:nrf52:somethingelse          # a different nRF52840 board
```

**Calling `arduino-cli` directly** instead of `make`? Then you must supply the flags yourself — the build
`#error`s without them (so a forgotten flag fails loudly instead of shipping a broken/deadlock-prone image):

```bash
arduino-cli compile -b adafruit:nrf52:feather52840 --build-property "build.extra_flags=-DNRF52840_XXAA {build.flags.usb} -DCFG_TUD_HID=6 -DCFG_TUD_TASK_QUEUE_SZ=512 -DCFG_TUD_VENDOR_TX_BUFSIZE=256" OpenPuck
```

## 5. Upload the firmware

### Makerdiary nRF52840 MDK USB Dongle

If you only want to install or update OpenPuck, use the
[step-by-step Makerdiary user guide](./MAKERDIARY_SETUP.md). The instructions
below include developer build details and recovery information.

The Makerdiary target is deliberately separate from the normal Pro Micro build:

```bash
make build-makerdiary
```

It produces:

```text
build/makerdiary/OpenPuck.ino.hex
build/makerdiary/OpenPuck-makerdiary-mdk.uf2
```

The target uses the Adafruit nRF52 core as its runtime, replaces the Feather
variant with the repo-local Makerdiary pin and clock configuration, and links
the application at `0x26000` for S140 6.1.1. The build fails if any application
data falls outside `0x26000`–`0xF3FFF`, protecting the resident Makerdiary
bootloader at `0xF4000`.

`build-makerdiary` also generates `OpenPuck/git_version.h`, so a local build
reports its git hash in the WebUSB panel instead of `unknown`. A tagged release
reports the release version. A local tree with uncommitted files is correctly
marked `dirty`.

#### One-time S140 6.1.1 setup

OpenPuck's Adafruit nRF52840 runtime requires Nordic S140 6.1.1 and an
application origin of `0x26000`. Some Makerdiary dongles ship with an older
S132-based image, which is not compatible even though the UF2 bootloader itself
works.

Use the release asset whose name begins
`makerdiary-s132-to-s140-6.1.1-bootloader-`. It contains S140 6.1.1 and the
OpenPuck Makerdiary bootloader. The package accepts the factory S132 5.1.0
firmware ID (`0xA5`).

1. Double-click the dongle button to enter its serial DFU bootloader.
2. Find the bootloader's serial port:

   ```bash
   arduino-cli board list
   ```

3. Install the package, replacing the port with the one reported above:

   ```bash
   adafruit-nrfutil --verbose dfu serial \
     --package makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip \
     -p /dev/cu.usbmodem1101 -b 115200
   ```

   On Linux the port is normally `/dev/ttyACM0`; on Windows it resembles
   `COM5`.
4. Allow the dongle to restart. One additional automatic reset is expected on
   the modified bootloader's first boot.
5. Double-click the button and inspect `UF2BOOT/INFO_UF2.TXT`. It should
   report `SoftDevice: S140 6.1.1`.

The nRF52 serial DFU format converts its HEX inputs into a contiguous BIN
payload, so it cannot carry arbitrary UICR address records. The modified
bootloader handles that limitation before enabling the SoftDevice: if both
reset selectors are erased, it writes P0.18 to both selectors and resets once.
If both are already P0.18, it proceeds without another write or reset. If
either contains a different value, it leaves both untouched.

Makerdiary V1.1 connects P0.16 to P0.18 so OpenPuck can perform a complete pin
reset. This is required for prompt mode changes because the nRF52840 watchdog
survives a software reset.

##### SWD installation and recovery

SWD is not required for the normal one-time upgrade, but it remains the
recovery method if serial DFU fails or the bootloader no longer starts:

1. Connect a CMSIS-DAP probe to the dongle's debug pads:

   ```text
   SWDIO -> DIO
   SWCLK -> CLK
   GND   -> GND
   ```

   Power the dongle from USB. A Raspberry Pi Debug Probe works; use its
   **DEBUG**, not UART, connector.
2. Install pyOCD and IntelHex in a virtual environment and confirm that pyOCD
   sees the probe:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   python -m pip install pyocd intelhex
   pyocd list
   ```

3. Program the combined SWD release asset:

   ```bash
   pyocd load -t nrf52840 -M halt -e sector \
     makerdiary-s140-6.1.1-bootloader-0.7.1-openpuck1-swd.hex
   ```

   The combined asset includes S140, the modified bootloader, and P0.18's two
   reset-selector records. Do not convert it to an application UF2 or copy it
   to `UF2BOOT`.
4. Verify the UICR configuration:

   ```bash
   pyocd commander -t nrf52840
   ```

   At the `pyocd>` prompt:

   ```text
   read32 0x10001014 8
   read32 0x10001200 8
   exit
   ```

   The two reads should report:

   ```text
   10001014:  000f4000 000fe000
   10001200:  00000012 00000012
   ```

5. Unplug and reconnect the dongle, then double-click its button. Inspect
   `UF2BOOT/INFO_UF2.TXT`; it should report `SoftDevice: S140 6.1.1`.

Optional but recommended before programming: use
`pyocd commander -t nrf52840` and
save the original flash and UICR:

```text
savemem 0x00000000 0x00100000 factory-flash.bin
savemem 0x10001000 0x00000400 uicr.bin
```

The combined image is produced from the same bootloader-only HEX used by the
serial package. `tools/enable-makerdiary-reset.py` remains in the repository so
reproducible SWD images begin with reset already configured; its safety checks
preserve the bootloader and MBR parameter addresses.

The pinned bootloader source, patch, build procedure, and decision test are in
[`bootloader/makerdiary`](../bootloader/makerdiary/).

See Makerdiary's
[UF2 bootloader guide](https://wiki.makerdiary.com/nrf52840-mdk-usb-dongle/programming/uf2boot/)
and [pyOCD/DAPLink guide](https://wiki.makerdiary.com/nrf52840-mdk-usb-dongle/programming/daplink/)
for the vendor's full programming instructions.

#### Normal Makerdiary updates

After the one-time S140 setup, the debugger is no longer needed:

1. Run `make build-makerdiary`, or download the release asset whose name ends
   in `-makerdiary-mdk.uf2`.
2. Double-click the dongle button. `UF2BOOT` mounts and the RGB LED turns
   green.
3. Drag `OpenPuck-makerdiary-mdk.uf2` onto `UF2BOOT`.
4. Wait for the red programming blink to finish, then unplug and reconnect the
   dongle.

Do not flash the standard/Pro Micro OpenPuck UF2 onto this board.

The WebUSB panel intentionally reports **manual UF2 only** for this target.
Staged panel updates and Adafruit-specific software DFU commands are disabled;
the Makerdiary bootloader remains the simple recovery and update path. Normal
configuration, pairing, status, and factory erase in the panel still work.

### Pro Micro and other standard nRF52840 boards

The quickest path is `make`. The serial port is a **required argument** (find it with `arduino-cli board list`):

```bash
make flash /dev/cu.usbmodem1101    # upload the most recent build to that port
make deploy /dev/cu.usbmodem1101   # build + flash in one step (same build overrides as `make build`)
```

Use the port for your OS: macOS `/dev/cu.usbmodem*`, Linux `/dev/ttyACM0`, Windows `COM5`.

> **DFU note:** in puck (Steam/Lizard) mode the firmware drops the CDC serial port to free a USB endpoint, so `arduino-cli` can't auto-reset the board into its bootloader. If the upload can't connect, put the board in DFU mode first by **double-tapping RST**, then `make flash <bootloader-port>` (re-check `arduino-cli board list` — the port can change in DFU mode). The drag-and-drop UF2 path in §5b also works.

### Manual upload (without `make`)

Find the board port with `arduino-cli board list`, then:

### macOS / Linux

```bash
arduino-cli upload \
  -b adafruit:nrf52:feather52840 \
  -p /dev/ttyACM0 \
  OpenPuck
```

Replace `/dev/ttyACM0` with the actual port. On macOS it is usually `/dev/cu.usbmodem*`.

### Windows

Find the COM port:

```powershell
arduino-cli board list
```

Upload:

```powershell
arduino-cli upload `
  -b adafruit:nrf52:feather52840 `
  -p COM5 `
  OpenPuck
```

Replace `COM5` with the actual board port.

## 5b. Upload via DFU (nRF52840 UF2 bootloader)

If the board has the **Adafruit nRF52 UF2 bootloader** (common on Pro Micro nRF52840 boards), you can upload by dragging the compiled `.uf2` file onto the board's mass-storage volume:

1. **Double-tap the RST button**. The board mounts as a **UF2BOOT** / **NRF52BOOT** drive.
2. Locate the compiled `.uf2` file:

   ```bash
   # After a successful `arduino-cli compile`, find the .uf2 in the build directory:
   ls /tmp/arduino/cores/adafruit_nrf52_adafruit52840/*.uf2
   # or, on Windows, look in %TEMP%\arduino\...
   ```

3. **Copy the `.uf2` file** onto the UF2BOOT drive. The board auto-ejects and reboots with the new firmware.

Alternatively, use the **adafruit-nrfutil DFU** Python tool with the board in DFU mode (bootloader LED pulsing):

```bash
# Enter DFU mode (double-tap RST). On Linux/macOS:
adafruit-nrfutil --verbose dfu serial --package OpenPuck/OpenPuck.ino.adafruit_nrf52_feather52840.zip -p /dev/ttyACM0 -b 115200

# On Windows (PowerShell):
adafruit-nrfutil --verbose dfu serial --package OpenPuck/OpenPuck.ino.adafruit_nrf52_feather52840.zip -p COM5 -b 115200
```

Replace the port (`/dev/ttyACM0` / `COM5`) with the actual board port.

> **Note:** The `.zip` package is generated automatically by `arduino-cli compile` when the Adafruit nRF52 core is used. If it is missing, ensure `adafruit-nrfutil` is installed and recompile.

### Flashing from the WebUSB panel (no tools, no drag-and-drop)

A board already running OpenPuck (status protocol v15+) can be updated entirely from the
[WebUSB configurator](https://safijari.github.io/openpuck/)'s **Firmware update** tab: drag-and-drop a
`.uf2` (or click to browse), or pick a version from the built-in **releases list** — each release offers the
standard build or, via its checkbox, the `-factory-reset` build (wipes settings + pairing once on first
boot). A blocking modal shows download/transfer/verify/apply progress and reports the old → new build once
the puck reconnects. Under the hood the panel extracts the app image from the `.uf2` and streams it over the
normal WebUSB connection into spare flash high in the app region (~15 s; the running firmware keeps working);
the firmware CRC32-verifies what landed and commits a one-page "apply on reboot" record; a final automatic
reboot copies staged→app from RAM (~5 s dark) and comes back up on the new firmware. See
`OpenPuck/fw_update.h` for the design.

> **Release downloads / the `firmware` branch:** GitHub's release-asset CDN sends no CORS headers, so the
> browser cannot fetch release assets directly. The release workflow therefore mirrors every OpenPuck `.uf2`
> onto the orphan **`firmware`** branch, and the panel downloads from
> `raw.githubusercontent.com/safijari/openpuck/firmware/<asset>` (which is CORS-clean). If a release is
> missing from the mirror, the panel falls back to opening the asset in a new tab for manual drag-and-drop.

Failure safety: **nothing is armed until the staged image verifies in flash**, so a disconnect, error, or
power cut during the transfer leaves the current firmware untouched. The apply step erases the app's vector
page first and rewrites it last (first word dead-last), so even a power cut mid-apply leaves the board
"app-less" — the resident UF2 bootloader then keeps it as the UF2BOOT drive for drag-and-drop recovery. A
half-flashed, crash-looping state is not reachable.

## 6. Factory reset (erase persistent storage)

Re-flashing firmware does **not** erase the board's internal LittleFS. The paired-controller bond (`bonds.bin`) and every saved setting (`cfg.bin`: USB mode, chord assignments, back-paddle map, mouse sensitivity) survive a fresh build and upload. To bring a board up in a truly clean state — a new unit, a hand-me-down with a stale bond, or a corrupted config — wipe the filesystem with one of:

- **Recovery build (`-DOPK_FACTORY_RESET=1`):** a firmware that wipes all persistent storage **once, on the first boot after flashing**, then behaves like a normal build that persists settings. Use it to recover a board from a bad config/bond without a console or panel:

  ```bash
  ./gen_version.sh   # recommended: embeds version (when tagged) + git hash provenance
  make build-recovery
  ```

  (`make build-recovery` is just `make build` plus `-DOPK_FACTORY_RESET=1`; the usual USB flags are still baked in.)

  It is **not** a wipe-every-boot image: after the one-time reset it stamps a tag file with the build's git hash, so subsequent boots skip the wipe and persist normally. Flashing this same image again won't re-wipe (the tag matches); flashing a **different** build (different git hash) re-triggers the one-time reset. For an on-demand wipe at any time, use the WebUSB button or serial `ERASE-ALL` below. Re-pair the controller after a reset.
- **WebUSB panel (any mode):** open the panel (§8), and in the maintenance card click **⚠ Factory erase**. Confirm the two warning dialogs and type `ERASE` when prompted. The board reformats its filesystem and reboots to factory defaults. This works in every USB mode.
- **Serial console (CDC):** connect to the board's serial port at 115200 baud and send the line `ERASE-ALL` (exact, all caps). Same effect: reformat + reboot.

Both reformat the entire internal filesystem (`cfg.bin` + `bonds.bin` and anything else), so the action is irreversible and the controller must be **re-paired afterwards** (see §7).

Note on the serial method: puck (Steam/Lizard) mode drops the CDC console by default to free a USB endpoint for the wake-mouse interface, so the serial port may not be present in that mode. Either arm the one-shot debug CDC first (panel debug-CDC toggle / `D` console command, which keeps the console for the next boot), or just use the WebUSB **Factory erase** button, which is available in all modes.

## 7. Pair and verify

1. Flash the board.
2. Plug it into the host.
3. In Steam mode it enumerates as a puck-compatible device.
4. Pair the controller to one of the bond slots.
5. Verify that the slot returns `0xB4 = 0x02` when connected.

## 8. Run the WebUSB app locally

WebUSB requires a secure context. `http://localhost` qualifies.

### macOS / Linux

```bash
cd docs
python3 -m http.server 8008
```

Open:

```text
http://localhost:8008
```

### Windows

```powershell
cd docs
py -m http.server 8008
```

Open:

```text
http://localhost:8008
```

## 9. Known operational details

- Chrome or Edge is required for WebUSB.
- The board re-enumerates on USB mode switches.
- Poll interval tuning in the WebUSB app is session-only by design.
- Bonds persist in the board's internal filesystem.
