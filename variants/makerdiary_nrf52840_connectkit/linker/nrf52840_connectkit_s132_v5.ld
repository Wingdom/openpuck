/* Linker script to configure memory regions.
 *
 * The Connect Kit ships from the factory with a real Nordic S132 5.1.0 SoftDevice already resident in
 * flash (confirmed from this unit's INFO_UF2.TXT) under a Makerdiary UF2 bootloader forked from
 * adafruit/Adafruit_nRF52_Bootloader (github.com/makerdiary/uf2-bootloader). We deliberately do NOT
 * replace either: the bootloader has no board definition upstream to safely rebuild against, and this
 * board has no SWD probe available as a recovery path if a from-scratch board definition had a bug.
 *
 * Instead this script places the app where the resident bootloader already expects it: S132 v5.1.0's
 * declared application start address is 0x23000 (Nordic DevZone, S132 v5.1.0 resource requirements --
 * the SoftDevice's own code ends near 0x1F084, but 0x23000 is the address Nordic reserves for binary
 * compatibility across S132 5.x minor versions, and what the bootloader's own non-DFU boot path reads
 * back from the installed SoftDevice to compute its jump target). This is 0x3000 lower than the S140
 * 6.1.1 app start (0x26000) every other board in this repo uses -- OpenPuck never calls into the
 * SoftDevice (bare-metal RF, no BLE stack), so overlapping its now-irrelevant tail bytes is harmless.
 *
 * LittleFS keeps the stock Adafruit address (0xED000, InternalFileSystem.cpp) -- the Connect Kit's
 * bootloader occupies 0xF4000-0x100000, same as every other Adafruit-lineage board, so the standard
 * layout already leaves the usual margin and needs no relocation (contrast mdbt50q-cx, whose bootloader
 * starts at 0xE0000 and does need tools/patch_bsp_lfs.py).
 */

SEARCH_DIR(.)
GROUP(-lgcc -lc -lnosys)

MEMORY
{
  FLASH (rx)     : ORIGIN = 0x23000, LENGTH = 0xED000 - 0x23000

  RAM (rwx) :  ORIGIN = 0x20006000, LENGTH = 0x20040000 - 0x20006000
}

SECTIONS
{
  . = ALIGN(4);
  .svc_data :
  {
    PROVIDE(__start_svc_data = .);
    KEEP(*(.svc_data))
    PROVIDE(__stop_svc_data = .);
  } > RAM

  .fs_data :
  {
    PROVIDE(__start_fs_data = .);
    KEEP(*(.fs_data))
    PROVIDE(__stop_fs_data = .);
  } > RAM
} INSERT AFTER .data;

INCLUDE "nrf52_common.ld"
