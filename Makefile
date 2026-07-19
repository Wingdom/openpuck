# OpenPuck developer convenience targets.

# Pin to clang-format 18 to match CI; output differs between versions, so a
# mismatch would make CI reject locally-formatted code. Resolve the binary in
# order of preference: the apt-style versioned name (CI / Linux), the Homebrew
# llvm@18 keg (macOS), then a bare clang-format as a last resort. Override with
# `make format CLANG_FORMAT=/path/to/clang-format` if yours lives elsewhere.
CLANG_FORMAT ?= $(shell command -v clang-format-18 \
	|| ([ -x /opt/homebrew/opt/llvm@18/bin/clang-format ] && echo /opt/homebrew/opt/llvm@18/bin/clang-format) \
	|| ([ -x /usr/local/opt/llvm@18/bin/clang-format ] && echo /usr/local/opt/llvm@18/bin/clang-format) \
	|| command -v clang-format)

# All hand-written C/C++ sources. Generated headers (git_version.h) are
# gitignored and excluded here so formatting never touches them.
FORMAT_FILES := $(shell find OpenPuck ReversePuckFirmware puck_sniffer pairtui \
	\( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o -name '*.ino' \) \
	-not -name 'git_version.h')

# --- firmware build ---------------------------------------------------------
# The OpenPuck firmware needs two TinyUSB config values that differ from the Adafruit nRF52 core defaults:
#   CFG_TUD_HID=6            -- four HID interfaces (Steam mode exposes four puck slots) plus one for mouse 
#								and one for WebUSB; core default is 2.
#   CFG_TUD_TASK_QUEUE_SZ=64 -- deeper usbd event queue; the default 16 deadlocks the loop task under comms
#                               load -> watchdog reset (see OpenPuck.ino + docs/BUILD_AND_DEPLOY.md).
#   CFG_TUD_VENDOR_TX_BUFSIZE=256 -- the WebUSB status blob is ~118 B; the core default 64 can't hold it whole,
#                               so the panel send (which drops rather than blocks when the FIFO is full) could
#                               never fit a frame -> blank panel. Sized to hold a full blob with headroom.
# They're baked in here so a normal build is just `make build` -- no need to remember the flags. Override any
# on the command line, e.g.   make build CFG_TUD_HID=8 CFG_TUD_TASK_QUEUE_SZ=128
# or add your own defines:     make build EXTRA_FLAGS="-DOPK_LOG=1"
FQBN ?= adafruit:nrf52:feather52840
CFG_TUD_HID ?= 6
# Optional output paths; when set, --clean is implied and build artifacts land in OUTPUT_DIR.
# Used by CI: make build BUILD_PATH=build/cache/openpuck OUTPUT_DIR=build/openpuck
BUILD_PATH ?=
OUTPUT_DIR ?=
# Deep so a loop()-context sendReport never blocks on a full usbd event queue (the watchdog path). Sends run
# from loop() now (usbTxPump) for stable RF timing, so this depth is what keeps that block from happening.
CFG_TUD_TASK_QUEUE_SZ ?= 512
# Must hold a whole WebUSB status blob (~118 B) so the drop-on-full panel send can fit one; core default 64 is
# too small and would silently drop every frame (blank panel / stale mappings).
CFG_TUD_VENDOR_TX_BUFSIZE ?= 256
EXTRA_FLAGS ?=
# {build.flags.usb} is expanded by arduino-cli (VID/PID/strings); pass it through verbatim.
USB_EXTRA_FLAGS = -DNRF52840_XXAA {build.flags.usb} -DCFG_TUD_HID=$(CFG_TUD_HID) -DCFG_TUD_TASK_QUEUE_SZ=$(CFG_TUD_TASK_QUEUE_SZ) -DCFG_TUD_VENDOR_TX_BUFSIZE=$(CFG_TUD_VENDOR_TX_BUFSIZE) $(EXTRA_FLAGS)
# When BUILD_PATH is set, --clean + path flags are injected; omitted for fast incremental dev builds.
_PATH_FLAGS = $(if $(BUILD_PATH),--clean --build-path $(BUILD_PATH) --output-dir $(OUTPUT_DIR))

# `flash`/`deploy` take the serial port as a REQUIRED POSITIONAL arg: `make flash /dev/cu.usbmodem1101`.
# (No auto-detect -- uploading to a guessed serial port risks writing to the wrong device. List with
# `arduino-cli board list`.) FLASH_PORT = whatever goal isn't one of our real targets; the catch-all rule at
# the bottom swallows it so make doesn't try to build the port path as a target.
FLASH_PORT := $(filter-out format format-check check build build-recovery build-mdbt50q-cx reversepuck reversepuck-flash reversepuck-deploy flash deploy,$(MAKECMDGOALS))
UPLOAD = arduino-cli upload -b $(FQBN) -p "$(FLASH_PORT)" OpenPuck

# ReversePuck (controller dongle, 28DE:1302) build flags. It has ONE HID interface (core default 2 is fine),
# so it doesn't need CFG_TUD_HID; it DOES need the deeper vendor TX FIFO to hold the 0xAC paired-pucks list
# whole, and the deeper usbd task queue keeps loop()-context WebUSB/CDC/HID sends off the watchdog path.
RP_USB_FLAGS = -DNRF52840_XXAA {build.flags.usb} -DCFG_TUD_TASK_QUEUE_SZ=$(CFG_TUD_TASK_QUEUE_SZ) -DCFG_TUD_VENDOR_TX_BUFSIZE=$(CFG_TUD_VENDOR_TX_BUFSIZE) $(EXTRA_FLAGS)
RP_UPLOAD = arduino-cli upload -b $(FQBN) -p "$(FLASH_PORT)" ReversePuckFirmware

.PHONY: format format-check check build build-recovery build-mdbt50q-cx reversepuck reversepuck-flash reversepuck-deploy flash deploy

## Compile the firmware with the required USB flags baked in. Override CFG_TUD_HID / CFG_TUD_TASK_QUEUE_SZ /
## EXTRA_FLAGS / FQBN as make variables if needed.
build:
	arduino-cli compile -b $(FQBN) $(_PATH_FLAGS) --build-property "build.extra_flags=$(USB_EXTRA_FLAGS)" OpenPuck

## One-time factory-reset recovery image (wipes persistent storage once on first boot). See §6 of the build doc.
build-recovery:
	$(MAKE) build BUILD_PATH=$(BUILD_PATH) OUTPUT_DIR=$(OUTPUT_DIR) EXTRA_FLAGS="$(EXTRA_FLAGS) -DOPK_FACTORY_RESET=1"

## Build a signed nrfutil DFU package (SoftDevice s140_6.1.1 + OpenPuck app) for a Raytac MDBT50Q-CX / PCA10059
## dongle running the stock Nordic Open Bootloader. Requires: nrfutil (Nordic Rust binary) with the
## `nrf5sdk-tools` module installed. OUTPUT_DIR is mandatory; BUILD_PATH is recommended (else build/cache).
## An ephemeral ECDSA signing key is generated per run -- the Nordic Open Bootloader on this dongle does NOT
## verify signatures (NRF_DFU_REQUIRE_SIGNED_APP_UPDATE=0), so a fresh key is fine and doesn't break existing
## installs. See the OPK_TARGET_NORDIC_DONGLE branches in fw_update.cpp / fault_diag.cpp for the flash-layout
## adjustments this target relies on, and tools/patch_bsp_lfs.py for the Adafruit-core LittleFS relocation.
build-mdbt50q-cx: BUILD_PATH ?= build/cache
build-mdbt50q-cx:
	@[ -n "$(OUTPUT_DIR)" ] || { echo "usage: make build-mdbt50q-cx OUTPUT_DIR=build/out [BUILD_PATH=build/cache]"; exit 1; }
	@command -v nrfutil >/dev/null || { echo "nrfutil not found; install from https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/"; exit 1; }
	@nrfutil list 2>/dev/null | grep -q '^nrf5sdk-tools' || { echo "nrfutil nrf5sdk-tools module missing; run: nrfutil install nrf5sdk-tools"; exit 1; }
	python3 tools/patch_bsp_lfs.py 0xD9000
	$(MAKE) build BUILD_PATH=$(BUILD_PATH) OUTPUT_DIR=$(OUTPUT_DIR) EXTRA_FLAGS="$(EXTRA_FLAGS) -DOPK_TARGET_NORDIC_DONGLE=1"
	python3 tools/extract_s140.py $(OUTPUT_DIR)/s140_nrf52_6.1.1_softdevice.hex
	nrfutil nrf5sdk-tools keys generate $(OUTPUT_DIR)/dfu_key.pem
	# Full package: SD s140_6.1.1 + app. Use for the FIRST flash on a dongle (which has no SoftDevice),
	# or as a recovery image. --sd-req 0x00,0xB6 accepts either a fresh dongle or one already updated.
	nrfutil nrf5sdk-tools pkg generate \
		--hw-version 52 \
		--sd-req 0x00,0xB6 \
		--sd-id 0xB6 \
		--application $(OUTPUT_DIR)/OpenPuck.ino.hex \
		--application-version 1 \
		--softdevice $(OUTPUT_DIR)/s140_nrf52_6.1.1_softdevice.hex \
		--key-file $(OUTPUT_DIR)/dfu_key.pem \
		$(OUTPUT_DIR)/openpuck-mdbt50q-cx.zip
	# App-only package: skips the SoftDevice re-flash on subsequent updates (~15 s over CDC vs ~30 s for
	# the full zip). --sd-req 0xB6 means the dongle MUST already have s140_6.1.1; the Nordic bootloader
	# rejects this package on a fresh dongle -- desirable, forces the user to the full zip for first install.
	nrfutil nrf5sdk-tools pkg generate \
		--hw-version 52 \
		--sd-req 0xB6 \
		--application $(OUTPUT_DIR)/OpenPuck.ino.hex \
		--application-version 1 \
		--key-file $(OUTPUT_DIR)/dfu_key.pem \
		$(OUTPUT_DIR)/openpuck-mdbt50q-cx-app.zip
	@echo
	@echo "MDBT50Q-CX DFU packages:"
	@echo "  $(OUTPUT_DIR)/openpuck-mdbt50q-cx.zip       (SD + app, ~330 KB -- first flash / recovery)"
	@echo "  $(OUTPUT_DIR)/openpuck-mdbt50q-cx-app.zip   (app-only,  ~190 KB -- subsequent updates)"
	@echo
	@echo "Flash: nrfutil nrf5sdk-tools dfu usb-serial -pkg <zip> -p /dev/serial/by-id/usb-Nordic_Semiconductor_Open_DFU_Bootloader_*-if00"

## Compile the ReversePuck controller dongle firmware (28DE:1302) with its WebUSB vendor flags baked in.
reversepuck:
	arduino-cli compile -b $(FQBN) $(_PATH_FLAGS) --build-property "build.extra_flags=$(RP_USB_FLAGS)" ReversePuckFirmware

## Upload the most recent ReversePuck build. Usage: make reversepuck-flash <port>
reversepuck-flash:
	@[ -n "$(FLASH_PORT)" ] || { echo "usage: make reversepuck-flash <port>   e.g. make reversepuck-flash /dev/cu.usbmodem1101"; exit 1; }
	$(RP_UPLOAD)

## Build then upload the ReversePuck dongle in one step. Usage: make reversepuck-deploy <port>
reversepuck-deploy:
	@[ -n "$(FLASH_PORT)" ] || { echo "usage: make reversepuck-deploy <port>   e.g. make reversepuck-deploy /dev/cu.usbmodem1101"; exit 1; }
	$(MAKE) reversepuck BUILD_PATH=$(BUILD_PATH) OUTPUT_DIR=$(OUTPUT_DIR)
	$(RP_UPLOAD)

## Upload the most recent build. Usage: make flash <port>   e.g.  make flash /dev/cu.usbmodem1101
## The board may need DFU/bootloader mode first (double-tap RST): puck (Steam/Lizard) mode drops the CDC port
## so arduino-cli can't auto-reset it -- see docs/BUILD_AND_DEPLOY.md.
flash:
	@[ -n "$(FLASH_PORT)" ] || { echo "usage: make flash <port>   e.g. make flash /dev/cu.usbmodem1101   (list ports: arduino-cli board list)"; exit 1; }
	$(UPLOAD)

## Build then upload in one step. Usage: make deploy <port>   (same build overrides as `build`).
deploy:
	@[ -n "$(FLASH_PORT)" ] || { echo "usage: make deploy <port>   e.g. make deploy /dev/cu.usbmodem1101"; exit 1; }
	$(MAKE) build BUILD_PATH=$(BUILD_PATH) OUTPUT_DIR=$(OUTPUT_DIR)
	$(UPLOAD)

# Swallow the positional <port> arg so make doesn't error trying to build it as a target. Scoped to things
# that look like a serial port (so a real typo like `make buld` still errors instead of silently no-op'ing).
/dev/% COM% tty% cu.%:
	@:

## Reformat all C/C++ sources in place using the Linux kernel style.
format:
	$(CLANG_FORMAT) -i $(FORMAT_FILES)

## Verify all C/C++ sources are formatted; exit non-zero if any differ.
## Used by CI to reject unformatted code.
format-check:
	$(CLANG_FORMAT) --dry-run --Werror $(FORMAT_FILES)

## Everything CI gates on.
check: format-check
