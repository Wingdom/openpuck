#pragma once

#include "WVariant.h"

#define VARIANT_MCK (64000000ul)
#define USE_LFXO

#define PINS_COUNT (48)
#define NUM_DIGITAL_PINS (48)
#define NUM_ANALOG_INPUTS (8)
#define NUM_ANALOG_OUTPUTS (0)
#define ADC_RESOLUTION 14

// Makerdiary nRF52840 MDK USB Dongle V1.1 RGB LED, active-low.
#define PIN_LED_RED (23)
#define PIN_LED_GREEN (22)
#define PIN_LED_BLUE (24)
#define PIN_LED1 PIN_LED_RED
#define PIN_LED2 PIN_LED_GREEN
#define PIN_LED3 PIN_LED_BLUE
#define LED_BUILTIN PIN_LED_RED
#define LED_CONN PIN_LED_BLUE
#define LED_STATE_ON 0

// Steady blue while OpenPuck runs; replace it with red for a USB remote-wake request.
#define OPK_STATUS_LED_IDLE_PIN PIN_LED_BLUE
#define OPK_STATUS_LED_ACTIVITY_PIN PIN_LED_RED
#define OPK_STATUS_LED_ON LOW

#define PIN_BUTTON1 (18)
#define PIN_DFU PIN_BUTTON1

#define PIN_SERIAL1_RX (19)
#define PIN_SERIAL1_TX (20)

#define WIRE_INTERFACES_COUNT 1
#define PIN_WIRE_SDA (5)
#define PIN_WIRE_SCL (4)

#define SPI_INTERFACES_COUNT 0
