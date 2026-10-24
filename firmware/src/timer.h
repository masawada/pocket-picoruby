/*
 * 1 ms periodic tick from the CLINT machine timer, plus time helpers.
 */
#ifndef POCKET_TIMER_H
#define POCKET_TIMER_H

#include <stdint.h>

/* Install the trap vector and start the 1 ms tick with interrupts enabled. */
void timer_init(void);

/* Called from the timer interrupt every millisecond. NULL disables the call. */
void timer_set_tick_handler(void (*fn)(void));

uint64_t timer_uptime_us(void);
void timer_busy_wait_us(uint32_t us);

#endif
