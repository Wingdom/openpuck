# Makerdiary UF2 bootloader

OpenPuck mode changes need a complete hardware reset because the nRF52840
watchdog survives a software reset. Makerdiary V1.1 boards connect P0.16 to
P0.18, but factory dongles leave P0.18's reset selectors erased.

The patch in this directory makes the Makerdiary UF2 bootloader configure
`PSELRESET[0]` and `PSELRESET[1]` for P0.18 on its first boot. It writes only
when both fields are erased, leaves an existing or conflicting configuration
untouched, restores NVMC read mode, and then resets once.

## Pinned source

Apply the patch to Adafruit's bootloader at:

```text
repository: https://github.com/adafruit/Adafruit_nRF52_Bootloader.git
commit:     c87ea51b86b96f9b19458abfc6b37d4cb52e160b
```

That source uses the same library revisions reported by Makerdiary bootloader
0.7.1:

```text
nrfx:    7a4c9d
TinyUSB: 9775e769
UF2:     adbb8c7
```

Clone and build:

```bash
git clone https://github.com/adafruit/Adafruit_nRF52_Bootloader.git
cd Adafruit_nRF52_Bootloader
git checkout c87ea51b86b96f9b19458abfc6b37d4cb52e160b
git submodule update --init --recursive
git apply --ignore-whitespace \
  /path/to/0001-Configure-Makerdiary-reset-pin-on-first-boot.patch

make BOARD=mdk_nrf52840_dongle \
  GIT_VERSION=0.7.1-openpuck1 \
  CROSS_COMPILE=/path/to/arm-none-eabi-
```

The bootloader-only input for `adafruit-nrfutil dfu genpkg` is:

```text
_build/build-mdk_nrf52840_dongle/
  mdk_nrf52840_dongle_bootloader-0.7.1-openpuck1.hex
```

Create the factory-S132 serial upgrade package with:

```bash
adafruit-nrfutil dfu genpkg \
  --dev-type 0x0052 \
  --dev-revision 52840 \
  --sd-req 0xA5 \
  --softdevice \
    lib/softdevice/s140_nrf52_6.1.1/s140_nrf52_6.1.1_softdevice.hex \
  --bootloader \
    _build/build-mdk_nrf52840_dongle/mdk_nrf52840_dongle_bootloader-0.7.1-openpuck1.hex \
  makerdiary-s132-to-s140-6.1.1-bootloader-0.7.1-openpuck1.zip
```

The standard build also emits the combined S140 image. Run
`tools/enable-makerdiary-reset.py` from the OpenPuck repository on that image
before distributing it for SWD installation. This keeps SWD-installed boards
ready on their first boot while remaining compatible with the bootloader's
already-configured path.

```bash
python tools/enable-makerdiary-reset.py \
  mdk_nrf52840_dongle_bootloader-0.7.1-openpuck1_s140_6.1.1.hex \
  makerdiary-s140-6.1.1-bootloader-0.7.1-openpuck1-swd.hex
```

## Decision test

The patch includes a host-side test for erased, configured, and conflicting
UICR values:

```bash
cc -std=c11 -Wall -Wextra -Werror \
  -Isrc/boards/mdk_nrf52840_dongle \
  tests/test_makerdiary_reset_config.c \
  -o /tmp/test-makerdiary-reset-config
/tmp/test-makerdiary-reset-config
```

The serial DFU package must explicitly accept the factory S132 5.1.0 firmware
ID, `0xA5`. Do not replace it with the wildcard `0xFFFE` in a published
package.

## Hardware validation

The complete upgrade path was tested on a factory-S132 Makerdiary V1.1 dongle
on 24 July 2026:

1. Before the upgrade, UICR contained the expected bootloader and MBR parameter
   addresses, while both reset selectors were erased.
2. The factory serial bootloader accepted the S140 6.1.1 + modified bootloader
   package with SoftDevice requirement `0xA5`.
3. The modified bootloader started, programmed both reset selectors to P0.18,
   and completed its one automatic reset.
4. `UF2BOOT/INFO_UF2.TXT` reported bootloader `0.7.1-openpuck1` and
   `SoftDevice: S140 6.1.1`.
5. Both reset selectors read back as `0x00000012`; the bootloader and MBR
   parameter addresses were unchanged.
6. A Makerdiary OpenPuck UF2 started normally, controller mode changes reported
   `pin/replug` instead of a watchdog hang, and double-click bootloader entry
   still mounted `UF2BOOT`.
