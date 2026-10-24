/*
 * PicoRuby port for the Pocket: the HAL that mruby-task and picoruby-machine
 * expect (see vendor/picoruby/mrbgems/picoruby-machine/include/hal.h and
 * machine.h), modelled on ports/rp2040/machine.c minus USB and low power.
 *
 * stdout/stderr go to the on-screen console. There is no stdin.
 */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "hal.h"
#include "machine.h"
#include "platform.h"

#include "console.h"
#include "riscv.h"
#include "timer.h"

volatile int sigint_status = 0; /* MACHINE_SIG_NONE */

static mrb_state *mrb_;

/*-------------------------------------
 * Scheduler tick and interrupt control
 *------------------------------------*/

static void tick(void)
{
  if (mrb_) {
    picorb_tick(mrb_);
  }
}

void picorb_hal_init(mrb_state *mrb)
{
  mrb_ = mrb;
  timer_set_tick_handler(tick);
}

void picorb_hal_final(mrb_state *mrb)
{
  (void)mrb;
  timer_set_tick_handler(NULL);
  mrb_ = NULL;
}

void picorb_hal_enable_irq(void)
{
  csr_set(mstatus, MSTATUS_MIE);
}

void picorb_hal_disable_irq(void)
{
  csr_clear(mstatus, MSTATUS_MIE);
}

void picorb_hal_idle_cpu(mrb_state *mrb)
{
  (void)mrb;
  wfi();
}

void picorb_hal_sleep_us(mrb_state *mrb, mrb_int usec)
{
  (void)mrb;
  timer_busy_wait_us((uint32_t)usec);
}

/*-------------------------------------
 * Console output, no input
 *------------------------------------*/

int picorb_hal_write(int fd, const void *buf, int nbytes)
{
  if (nbytes <= 0) return 0;
  if (fd == FD_STDERR) {
    console_set_colour(CONSOLE_RED, CONSOLE_BLACK);
    console_write(buf, (size_t)nbytes);
    console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
  }
  else {
    console_write(buf, (size_t)nbytes);
  }
  return nbytes;
}

int picorb_hal_flush(int fd)
{
  (void)fd;
  display_flush();
  return 0;
}

void picorb_hal_abort(const char *s)
{
  if (s) {
    picorb_hal_write(FD_STDERR, s, (int)strlen(s));
  }
  csr_clear(mstatus, MSTATUS_MIE);
  for (;;) {
    wfi();
  }
}

bool picorb_hal_cdc_connected(uint8_t itf)
{
  (void)itf;
  return false;
}

int picorb_hal_cdc_write(uint8_t itf, const void *buf, int nbytes, uint32_t timeout_ms)
{
  (void)itf;
  (void)buf;
  (void)nbytes;
  (void)timeout_ms;
  return 0;
}

int picorb_hal_read_available(void)
{
  return 0;
}

int picorb_hal_getchar(void)
{
  return HAL_GETCHAR_EOF;
}

bool picorb_hal_stdin_push(uint8_t ch)
{
  (void)ch;
  return false;
}

/*-------------------------------------
 * IO::Console (picoruby-io-console)
 *------------------------------------*/

static bool raw_mode, raw_mode_saved;
static bool echo_mode = true, echo_mode_saved = true;

bool io_raw_q(void) { return raw_mode; }
void io_raw_bang(bool nonblock) { (void)nonblock; raw_mode_saved = raw_mode; raw_mode = true; }
void io_cooked_bang(void) { raw_mode_saved = raw_mode; raw_mode = false; }
void io_echo_eq(bool flag) { echo_mode_saved = echo_mode; echo_mode = flag; }
bool io_echo_q(void) { return echo_mode; }
void io__restore_termios(void) { raw_mode = raw_mode_saved; echo_mode = echo_mode_saved; }

/*-------------------------------------
 * Machine class
 *------------------------------------*/

machine_sleep_result_t Machine_sleep_timer(bool deep, uint32_t ms)
{
  if (deep) return MACHINE_SLEEP_EUNSUPPORTED;
  Machine_delay_ms(ms);
  return MACHINE_SLEEP_OK;
}

machine_sleep_result_t Machine_sleep_gpio(bool deep, int pin, bool edge, bool high)
{
  (void)deep;
  (void)pin;
  (void)edge;
  (void)high;
  return MACHINE_SLEEP_EUNSUPPORTED;
}

void Machine_delay_ms(uint32_t ms)
{
  timer_busy_wait_us(ms * 1000u);
}

void Machine_busy_wait_ms(uint32_t ms)
{
  timer_busy_wait_us(ms * 1000u);
}

void Machine_busy_wait_us(uint32_t us)
{
  timer_busy_wait_us(us);
}

bool Machine_get_unique_id(char *id_str)
{
  /* Callers pass a 17-byte buffer (rp2040 board id as hex). */
  memcpy(id_str, "POCKET0000000000", 17);
  return true;
}

void Machine_tud_task(void) {}
bool Machine_tud_mounted_q(void) { return false; }
bool Machine_bootsel_pressed_q(void) { return false; }
uint32_t Machine_stack_usage(void) { return 0; }

bool Machine_set_hwclock(const struct timespec *ts)
{
  (void)ts;
  return false;
}

bool Machine_get_hwclock(struct timespec *ts)
{
  (void)ts;
  return false;
}

void Machine_exit(int status)
{
  console_printf("\n[exit %d]\n", status);
}

void Machine_reboot(void)
{
  console_puts("\n[reboot is not supported; reset the core from the Pocket menu]\n");
}

uint64_t Machine_uptime_us(void)
{
  return timer_uptime_us();
}

/*-------------------------------------
 * picoruby-require / picoruby-env
 *------------------------------------*/

void Platform_name(char *buf, size_t size)
{
  if (size == 0) return;
  strncpy(buf, "Pocket", size - 1);
  buf[size - 1] = '\0';
}

void ENV_get_key_value(char **key, size_t *key_len, char **value, size_t *value_len)
{
  *key = NULL;
  *key_len = 0;
  *value = NULL;
  *value_len = 0;
}

int ENV_unsetenv(const char *name)
{
  (void)name;
  return 0;
}

int ENV_setenv(const char *name, const char *value, int override)
{
  (void)name;
  (void)value;
  (void)override;
  return 0;
}

long ENV_get_timezone_offset(void)
{
  return 0;
}
