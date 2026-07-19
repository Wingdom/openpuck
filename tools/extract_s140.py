#!/usr/bin/env python3
# Extract the S140 SoftDevice payload (flash 0x1000-0x26000) from the Adafruit_nRF52 BSP's combined
# bootloader hex, so it can be fed to `nrfutil nrf5sdk-tools pkg generate --softdevice`. Drops:
#   * the MBR at 0x0-0x1000 (already present on any dongle we care about; also, this bootloader can't rewrite it)
#   * the Adafruit UF2 bootloader at 0xF4000+ (must NOT overwrite the resident Nordic bootloader)
#   * UICR entries at 0x10001014+ (one-time-programmable; already set on the dongle)
#   * bootloader settings at 0xFD800+ (Adafruit-only; irrelevant to the Nordic bootloader)
#
# Usage:  python3 tools/extract_s140.py <output.hex> [--source <combined.hex>]
#         (default source: the Adafruit feather_nrf52840_express bootloader hex from the installed BSP)
import argparse
import pathlib
import sys

KEEP_LO = 0x1000
KEEP_HI = 0x26000


def default_source() -> pathlib.Path | None:
	home = pathlib.Path.home()
	roots = [home / ".arduino15/packages/adafruit/hardware/nrf52",
		 home / "Library/Arduino15/packages/adafruit/hardware/nrf52",
		 home / "AppData/Local/Arduino15/packages/adafruit/hardware/nrf52"]
	for r in roots:
		if not r.exists():
			continue
		hits = list(r.glob("*/bootloader/feather_nrf52840_express/"
				   "feather_nrf52840_express_bootloader-*_s140_6.1.1.hex"))
		if hits:
			return sorted(hits)[-1]
	return None


def emit(rec_type: int, addr16: int, data: bytes) -> str:
	n = len(data)
	head = bytes([n, (addr16 >> 8) & 0xFF, addr16 & 0xFF, rec_type]) + data
	chk = ((~sum(head) + 1) & 0xFF)
	return ":" + head.hex().upper() + f"{chk:02X}"


def extract(in_p: pathlib.Path, out_p: pathlib.Path) -> tuple[int, int]:
	out_lines: list[str] = []
	seg = 0
	cur_upper = None
	kept_lo = kept_hi = None
	for ln in in_p.read_text().splitlines():
		ln = ln.strip()
		if not ln.startswith(":"):
			continue
		n = int(ln[1:3], 16)
		a = int(ln[3:7], 16)
		t = int(ln[7:9], 16)
		if t == 0x02:
			seg = int(ln[9:13], 16) << 4
		elif t == 0x04:
			seg = int(ln[9:13], 16) << 16
		elif t == 0x00:
			addr = seg + a
			data = bytes.fromhex(ln[9:9 + 2 * n])
			lo = max(addr, KEEP_LO)
			hi = min(addr + n, KEEP_HI)
			if lo >= hi:
				continue
			payload = data[lo - addr:hi - addr]
			new_upper = lo & 0xFFFF0000
			if cur_upper != new_upper:
				out_lines.append(emit(0x04, 0, bytes([(new_upper >> 24) & 0xFF,
								      (new_upper >> 16) & 0xFF])))
				cur_upper = new_upper
			out_lines.append(emit(0x00, lo & 0xFFFF, payload))
			kept_lo = lo if kept_lo is None else min(kept_lo, lo)
			kept_hi = hi if kept_hi is None else max(kept_hi, hi)
	out_lines.append(":00000001FF")
	out_p.write_text("\n".join(out_lines) + "\n")
	if kept_lo is None:
		raise SystemExit(f"ERROR: no S140 payload extracted from {in_p}")
	return kept_lo, kept_hi


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("output", help="output .hex path")
	ap.add_argument("--source", type=pathlib.Path, default=None,
			help="combined bootloader .hex to extract from (default: locate in ~/.arduino15)")
	args = ap.parse_args()
	src = args.source or default_source()
	if src is None:
		print("ERROR: Adafruit feather_nrf52840_express bootloader hex not found in ~/.arduino15",
		      file=sys.stderr)
		return 1
	lo, hi = extract(src, pathlib.Path(args.output))
	print(f"extracted {src.name} -> {args.output}  (range {lo:#010x}..{hi:#010x}, {hi-lo} B)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
