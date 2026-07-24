#!/usr/bin/env python3
"""Enable the Makerdiary MDK USB Dongle V1.1 self-reset circuit.

The official combined S140/UF2 bootloader HEX preserves P0.18 as a GPIO so the
button can be sampled while it is held during power-up. OpenPuck needs P0.18's
hardware-reset function instead: the V1.1 PCB connects P0.16 to P0.18, allowing
firmware to reset the complete chip (including the otherwise persistent WDT).

Patch the official combined image before its one-time SWD installation. Keeping
the bootloader and reset-selector records in one HEX lets pyOCD erase/program
the UICR sector as one complete operation.
"""

from argparse import ArgumentParser
from pathlib import Path

from intelhex import IntelHex


UICR_BOOTLOADER = 0x10001014
UICR_MBR_PARAMS = 0x10001018
UICR_PSELRESET0 = 0x10001200
UICR_PSELRESET1 = 0x10001204
MAKERDIARY_BOOTLOADER = 0x000F4000
MAKERDIARY_MBR_PARAMS = 0x000FE000
RESET_PIN = 18


def read_u32(image: IntelHex, address: int) -> int:
    return sum(image[address + offset] << (8 * offset) for offset in range(4))


def write_u32(image: IntelHex, address: int, value: int) -> None:
    for offset in range(4):
        image[address + offset] = (value >> (8 * offset)) & 0xFF


def main() -> None:
    parser = ArgumentParser(
        description=(
            "Patch Makerdiary's official combined S140/UF2 bootloader HEX "
            "to enable the V1.1 P0.16 -> P0.18 self-reset circuit."
        )
    )
    parser.add_argument("input", type=Path, help="official combined Makerdiary HEX")
    parser.add_argument("output", type=Path, help="patched HEX to flash over SWD")
    args = parser.parse_args()

    if args.input.resolve() == args.output.resolve():
        parser.error("input and output must be different files")

    image = IntelHex(str(args.input))
    expected = {
        UICR_BOOTLOADER: MAKERDIARY_BOOTLOADER,
        UICR_MBR_PARAMS: MAKERDIARY_MBR_PARAMS,
    }
    for address, value in expected.items():
        actual = read_u32(image, address)
        if actual != value:
            raise SystemExit(
                f"refusing to patch: 0x{address:08X} is 0x{actual:08X}, "
                f"expected 0x{value:08X}"
            )

    for address in (UICR_PSELRESET0, UICR_PSELRESET1):
        actual = read_u32(image, address)
        if actual not in (0xFFFFFFFF, RESET_PIN):
            raise SystemExit(
                f"refusing to patch: 0x{address:08X} is 0x{actual:08X}, "
                f"expected erased or P0.{RESET_PIN}"
            )
        write_u32(image, address, RESET_PIN)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.write_hex_file(str(args.output))
    print(f"Wrote {args.output}")
    print(
        "Preserved bootloader=0x000F4000, MBR params=0x000FE000; "
        "set PSELRESET[0/1]=P0.18"
    )


if __name__ == "__main__":
    main()
