#pragma once

#include "WVariant.h"

#define VARIANT_MCK (64000000ul)
#define USE_LFXO

#define PINS_COUNT (48)
#define NUM_DIGITAL_PINS (48)
#define NUM_ANALOG_INPUTS (8)
#define NUM_ANALOG_OUTPUTS (0)
#define ADC_RESOLUTION 14

// Makerdiary nRF52840 Connect Kit RGB LED (D1), active-low, common anode to VDD_NRF (schematic sheet 5).
#define PIN_LED_RED (42) // P1.10
#define PIN_LED_GREEN (43) // P1.11
#define PIN_LED_BLUE (44) // P1.12
#define PIN_LED1 PIN_LED_RED
#define PIN_LED2 PIN_LED_GREEN
#define PIN_LED3 PIN_LED_BLUE
#define LED_BUILTIN PIN_LED_RED
#define LED_CONN PIN_LED_BLUE
#define LED_STATE_ON 0

// Single green LED (D2), active-low, common anode to VDD_NRF (schematic sheet 2).
#define PIN_LED_GREEN2 (47) // P1.15

// Steady blue while OpenPuck runs; replaced by red for a USB remote-wake request (same convention as the
// Makerdiary MDK USB Dongle port).
#define OPK_STATUS_LED_IDLE_PIN PIN_LED_BLUE
#define OPK_STATUS_LED_ACTIVITY_PIN PIN_LED_RED
#define OPK_STATUS_LED_ON LOW

// USR button (SW1), active-low, needs the internal pull-up (schematic sheet 5).
#define PIN_BUTTON1 (32) // P1.00
#define PIN_DFU PIN_BUTTON1

// RESET button (SW2) shorts P0.18 to GND (schematic sheet 5). Unlike the Makerdiary MDK USB Dongle V1.1,
// there is no spare GPIO wired to this net -- OPK_SELF_RESET_PIN is deliberately NOT defined here, so
// modeSwitchReboot() (OpenPuck.ino) falls through to the standard USBDevice.detach()+NVIC_SystemReset()
// path, same as the Pro Micro and the mdbt50q-cx port.

// Placeholders only -- OpenPuck does not use Wire or Serial1. Pins chosen to avoid the QSPI flash
// (P0.17/19/20/21/22/23), the buttons/LEDs above, XL1/XL2 (P0.00/P0.01, LFXO), and NFC1/2 (P0.09/P0.10).
#define PIN_SERIAL1_RX (24) // P0.24
#define PIN_SERIAL1_TX (25) // P0.25

#define WIRE_INTERFACES_COUNT 1
#define PIN_WIRE_SDA (26) // P0.26
#define PIN_WIRE_SCL (27) // P0.27

#define SPI_INTERFACES_COUNT 0
