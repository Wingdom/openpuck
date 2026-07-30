#include "variant.h"

#include "nrf.h"
#include "wiring_constants.h"
#include "wiring_digital.h"

// Arduino pin N maps directly to nRF P0.N, then P1.(N - 32).
const uint32_t g_ADigitalPinMap[] = {
	0,  1,	2,  3,	4,  5,	6,  7,	8,  9,	10, 11, 12, 13, 14, 15,
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
	32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
};

static void selectLfCrystal()
{
	const uint32_t stateMask = CLOCK_LFCLKSTAT_STATE_Msk;
	const uint32_t sourceMask = CLOCK_LFCLKSTAT_SRC_Msk;
	const uint32_t crystal = CLOCK_LFCLKSTAT_SRC_Xtal
				 << CLOCK_LFCLKSTAT_SRC_Pos;

	/*
	 * The Connect Kit populates a 32.768 kHz crystal (Y2, schematic sheet 3), but the core's init()
	 * only selects LFXO if LFCLK isn't already running -- a source left running by the bootloader
	 * ignores that new selection, so stop it before restarting from the board's crystal.
	 */
	if ((NRF_CLOCK->LFCLKSTAT & (stateMask | sourceMask)) !=
	    (stateMask | crystal)) {
		NRF_CLOCK->TASKS_LFCLKSTOP = 1;
		while (NRF_CLOCK->LFCLKSTAT & stateMask)
			;

		NRF_CLOCK->LFCLKSRC = CLOCK_LFCLKSRC_SRC_Xtal
				      << CLOCK_LFCLKSRC_SRC_Pos;
		NRF_CLOCK->EVENTS_LFCLKSTARTED = 0;
		NRF_CLOCK->TASKS_LFCLKSTART = 1;
		while (!NRF_CLOCK->EVENTS_LFCLKSTARTED)
			;
	}
}

void initVariant()
{
	selectLfCrystal();

	pinMode(PIN_LED_RED, OUTPUT);
	pinMode(PIN_LED_GREEN, OUTPUT);
	pinMode(PIN_LED_BLUE, OUTPUT);
	pinMode(PIN_LED_GREEN2, OUTPUT);
	ledOff(PIN_LED_RED);
	ledOff(PIN_LED_GREEN);
	ledOff(PIN_LED_BLUE);
	ledOff(PIN_LED_GREEN2);
}
