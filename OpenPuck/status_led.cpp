#include <Arduino.h>
#include "status_led.h"

#define WAKE_LED_OFF ((WAKE_LED_ON) == HIGH ? LOW : HIGH)
#define PULSE_MS 500u // wake flash duration

#if defined(OPK_STATUS_LED_IDLE_PIN) && \
	defined(OPK_STATUS_LED_ACTIVITY_PIN) && defined(OPK_STATUS_LED_ON)
#define OPK_STATUS_LED_OFF ((OPK_STATUS_LED_ON) == HIGH ? LOW : HIGH)
#endif

static unsigned long g_pulseMs = 0;
static bool g_lit = false;

static void ledSetActivity(bool active)
{
#if defined(OPK_STATUS_LED_IDLE_PIN) && \
	defined(OPK_STATUS_LED_ACTIVITY_PIN) && defined(OPK_STATUS_LED_ON)
	digitalWrite(OPK_STATUS_LED_IDLE_PIN,
		     active ? OPK_STATUS_LED_OFF : OPK_STATUS_LED_ON);
	digitalWrite(OPK_STATUS_LED_ACTIVITY_PIN,
		     active ? OPK_STATUS_LED_ON : OPK_STATUS_LED_OFF);
#else
	const int level = active ? WAKE_LED_ON : WAKE_LED_OFF;
	digitalWrite(WAKE_LED_PIN_A, level);
	digitalWrite(WAKE_LED_PIN_B, level);
#endif
}

void ledInit()
{
#if defined(OPK_STATUS_LED_IDLE_PIN) && \
	defined(OPK_STATUS_LED_ACTIVITY_PIN) && defined(OPK_STATUS_LED_ON)
	pinMode(OPK_STATUS_LED_IDLE_PIN, OUTPUT);
	pinMode(OPK_STATUS_LED_ACTIVITY_PIN, OUTPUT);
#else
	pinMode(WAKE_LED_PIN_A, OUTPUT);
	pinMode(WAKE_LED_PIN_B, OUTPUT);
#endif
	ledSetActivity(false);
}

void ledWakePulse()
{
	g_pulseMs = millis();
	g_lit = true;

	// light immediately at the remoteWakeup() call site, not on the next loop
	ledSetActivity(true);
}

void ledTask()
{
	if (g_lit && millis() - g_pulseMs >= PULSE_MS) {
		g_lit = false;
		ledSetActivity(false);
	}
}
