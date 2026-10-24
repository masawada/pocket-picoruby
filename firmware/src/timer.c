#include "timer.h"

#include "console.h"
#include "litex.h"
#include "riscv.h"

#define TICKS_PER_MS ((uint64_t)CONFIG_CLOCK_FREQUENCY / 1000u)

static void (*tick_handler)(void);
static uint64_t next_tick;

static void timer_tick(void)
{
  uint64_t now = clint_mtime();
  next_tick += TICKS_PER_MS;
  if (next_tick <= now) {
    /* Interrupts were masked for longer than a period; do not pile up ticks. */
    next_tick = now + TICKS_PER_MS;
  }
  clint_set_mtimecmp(next_tick);
  if (tick_handler) {
    tick_handler();
  }
}

/*
 * GCC saves every register the handler touches (FP ones included) and
 * returns with mret. Direct-mode mtvec needs a 4-byte aligned address.
 */
__attribute__((interrupt("machine"), aligned(4)))
static void trap_handler(void)
{
  uint32_t cause = csr_read(mcause);
  if (cause == (MCAUSE_INTERRUPT | MCAUSE_MACHINE_TIMER)) {
    timer_tick();
    return;
  }

  /* Synchronous exception or an interrupt we never enabled: report and stop. */
  csr_clear(mstatus, MSTATUS_MIE);
  console_set_colour(CONSOLE_RED, CONSOLE_BLACK);
  console_printf("\n*** trap mcause=%08lx mepc=%08lx mtval=%08lx\n",
                 (unsigned long)cause, (unsigned long)csr_read(mepc), (unsigned long)csr_read(mtval));
  for (;;) {
    wfi();
  }
}

void timer_init(void)
{
  csr_write(mtvec, (uint32_t)(uintptr_t)trap_handler);
  next_tick = clint_mtime() + TICKS_PER_MS;
  clint_set_mtimecmp(next_tick);
  csr_set(mie, MIE_MTIE);
  csr_set(mstatus, MSTATUS_MIE);
}

void timer_set_tick_handler(void (*fn)(void))
{
  tick_handler = fn;
}

uint64_t timer_uptime_us(void)
{
  uint64_t t = clint_mtime();
  uint64_t hz = CONFIG_CLOCK_FREQUENCY;
  return (t / hz) * 1000000u + (t % hz) * 1000000u / hz;
}

void timer_busy_wait_us(uint32_t us)
{
  uint64_t until = clint_mtime() + (uint64_t)us * CONFIG_CLOCK_FREQUENCY / 1000000u;
  while (clint_mtime() < until) {
  }
}
