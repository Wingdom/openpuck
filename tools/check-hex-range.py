#!/usr/bin/env python3
"""Reject Intel HEX data outside one half-open address interval."""

import pathlib
import sys


def fail(message):
	print(f"check-hex-range.py: {message}", file=sys.stderr)
	raise SystemExit(1)


if len(sys.argv) != 4:
	fail("usage: check-hex-range.py FILE MIN_ADDR MAX_ADDR_EXCLUSIVE")

path = pathlib.Path(sys.argv[1])
minimum = int(sys.argv[2], 0)
maximum = int(sys.argv[3], 0)
base = 0
lowest = None
highest = None

for line_number, raw in enumerate(path.read_text().splitlines(), 1):
	if not raw.startswith(":"):
		fail(f"{path}:{line_number}: invalid Intel HEX record")
	try:
		record = bytes.fromhex(raw[1:])
	except ValueError as exc:
		fail(f"{path}:{line_number}: {exc}")
	if len(record) < 5 or record[0] + 5 != len(record):
		fail(f"{path}:{line_number}: invalid record length")
	if sum(record) & 0xFF:
		fail(f"{path}:{line_number}: checksum mismatch")

	count = record[0]
	offset = int.from_bytes(record[1:3], "big")
	record_type = record[3]
	data = record[4 : 4 + count]

	if record_type == 0x00 and count:
		start = base + offset
		end = start + count
		if start < minimum or end > maximum:
			fail(
				f"data 0x{start:08X}-0x{end - 1:08X} is outside "
				f"0x{minimum:08X}-0x{maximum - 1:08X}"
			)
		lowest = start if lowest is None else min(lowest, start)
		highest = end - 1 if highest is None else max(highest, end - 1)
	elif record_type == 0x02:
		if count != 2:
			fail(f"{path}:{line_number}: invalid segment-address record")
		base = int.from_bytes(data, "big") << 4
	elif record_type == 0x04:
		if count != 2:
			fail(f"{path}:{line_number}: invalid linear-address record")
		base = int.from_bytes(data, "big") << 16
	elif record_type == 0x01:
		break

if lowest is None:
	fail(f"{path}: contains no data records")

print(f"HEX data range: 0x{lowest:08X}-0x{highest:08X}")
