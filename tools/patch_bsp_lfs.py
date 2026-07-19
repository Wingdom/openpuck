#!/usr/bin/env python3
# Patch the installed Adafruit_nRF52 core's InternalFileSystem.cpp so LittleFS lives BELOW the Nordic Open
# Bootloader region on a Raytac MDBT50Q-CX / PCA10059 dongle (bootloader occupies 0xE0000-0xFE000; stock
# Adafruit places LittleFS at 0xED000-0xF4000, which sits inside it). Idempotent: exits 0 with a message if
# the file is already patched to the requested address.
#
# Usage:  python3 tools/patch_bsp_lfs.py [target_addr_hex]        default: 0xD9000
#         python3 tools/patch_bsp_lfs.py --restore                revert to Adafruit's original 0xED000
#
# Layout constraint: 7 pages of 0x1000 must end at or below 0xE0000 (Nordic bootloader start), so the target
# address must be <= 0xD9000. 0xD9000 lands the FS exactly against the bootloader with no slack -- that's
# fine because the bootloader is never written by an application boot.
import re
import sys
import pathlib

STOCK_ADDR = "0xED000"


def find_bsp_files() -> list[pathlib.Path]:
	home = pathlib.Path.home()
	roots = [home / ".arduino15/packages/adafruit/hardware/nrf52",
		 home / "Library/Arduino15/packages/adafruit/hardware/nrf52",
		 home / "AppData/Local/Arduino15/packages/adafruit/hardware/nrf52"]
	found: list[pathlib.Path] = []
	for r in roots:
		if not r.exists():
			continue
		found.extend(r.glob("*/libraries/InternalFileSytem/src/InternalFileSystem.cpp"))
	return found


def patch_one(f: pathlib.Path, target_addr: str) -> bool:
	# Line-scan under `#ifdef NRF52840_XXAA` for the FIRST `#define LFS_FLASH_ADDR 0x…`.
	# Robust to earlier hand-edits that inserted comment lines between the #ifdef and the #define
	# (the Adafruit stock file has them adjacent, but we don't want that to be a load-bearing shape).
	lines = f.read_text().splitlines(keepends=True)
	define_pat = re.compile(r"^(\s*#define\s+LFS_FLASH_ADDR\s+)(0x[0-9A-Fa-f]+)(.*\n?)$")
	in_block = False
	for i, ln in enumerate(lines):
		s = ln.lstrip()
		if s.startswith("#ifdef") and "NRF52840_XXAA" in s:
			in_block = True
			continue
		if s.startswith("#else") or s.startswith("#endif") or s.startswith("#elif"):
			if in_block:
				break
			continue
		if not in_block:
			continue
		m = define_pat.match(ln)
		if not m:
			continue
		current = m.group(2)
		if current.upper() == target_addr.upper():
			print(f"skip (already at {target_addr}): {f}")
			return True
		lines[i] = m.group(1) + target_addr + m.group(3)
		f.write_text("".join(lines))
		print(f"patched: {f}   ({current} -> {target_addr})")
		return True
	print(f"ERROR: LFS_FLASH_ADDR under `#ifdef NRF52840_XXAA` not found in {f}", file=sys.stderr)
	return False


def main() -> int:
	args = sys.argv[1:]
	if args and args[0] == "--restore":
		target = STOCK_ADDR
	else:
		target = args[0] if args else "0xD9000"
	target_int = int(target, 16)
	if target_int + 0x7000 > 0xE0000:
		print(f"ERROR: target {target} + 7 pages crosses the Nordic bootloader at 0xE0000",
		      file=sys.stderr)
		return 2
	files = find_bsp_files()
	if not files:
		print("ERROR: Adafruit_nRF52 BSP not found under ~/.arduino15 (or platform equivalent).",
		      file=sys.stderr)
		print("Install first: arduino-cli core install adafruit:nrf52", file=sys.stderr)
		return 1
	ok = True
	for f in files:
		if not patch_one(f, target):
			ok = False
	return 0 if ok else 3


if __name__ == "__main__":
	sys.exit(main())
