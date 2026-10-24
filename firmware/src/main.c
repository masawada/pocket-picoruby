/*
 * Boot PicoRuby, read the Ruby script from the "Script" data slot, compile it
 * on the device and run it. Output and exceptions appear on the on-screen
 * console. Picking another .rb from the Pocket menu resets the core, so this
 * runs again from the top.
 */
#include <stdint.h>
#include <string.h>

#include "picoruby.h"
#include <task.h>
#include <mruby/internal.h>
#include <mruby/string.h>
#include "hal.h"

#include "bridge.h"
#include "console.h"
#include "display.h"
#include "litex.h"
#include "riscv.h"
#include "timer.h"

#if !defined(PICORB_ALLOC_ESTALLOC)
#error "the Pocket port requires PICORB_ALLOC_ESTALLOC"
#endif
#include "estalloc_mruby.h"

/*
 * RAM layout (64 MB SDRAM):
 *   0x40000000  program (.text/.data/.bss), loaded from boot.bin
 *   0x40c00000  framebuffer DMA window (8 MB)
 *   0x41400000  Ruby heap (Estalloc) ...
 *   ... up to   0x43c00000, leaving 4 MB for the C stack below 0x44000000
 */
#define STACK_RESERVE (4u * 1024 * 1024)
#define RUBY_HEAP_BASE ((uintptr_t)VIDEO_FRAMEBUFFER_BASE + VIDEO_FRAMEBUFFER_SIZE)
#define RUBY_HEAP_END ((uintptr_t)MAIN_RAM_BASE + MAIN_RAM_SIZE - STACK_RESERVE)
#define RUBY_HEAP_SIZE (RUBY_HEAP_END - RUBY_HEAP_BASE)

/* data.json slot holding the user's .rb (see core/data.json). */
#define SCRIPT_SLOT 1
#define SCRIPT_MAX_SIZE (256 * 1024)
static uint8_t script_buf[SCRIPT_MAX_SIZE] __attribute__((aligned(4)));

extern mrb_state *global_mrb; /* defined in mruby-compiler (ccontext.c) */

static void halt(void)
{
  console_puts("\n-- halted --\n");
  for (;;) {
    wfi();
  }
}

static void print_exception(mrb_state *mrb, mrb_value exc)
{
  mrb->exc = NULL;
  mrb_value msg = mrb_funcall(mrb, exc, "message", 0);
  mrb->exc = NULL;
  console_set_colour(CONSOLE_RED, CONSOLE_BLACK);
  console_printf("%s: %s\n", mrb_obj_classname(mrb, exc),
                 mrb_string_p(msg) ? RSTRING_CSTR(mrb, msg) : "(no message)");
  mrb_value bt = mrb_exc_backtrace(mrb, exc);
  if (mrb_array_p(bt)) {
    for (mrb_int i = 0; i < RARRAY_LEN(bt); i++) {
      mrb_value line = mrb_ary_ref(mrb, bt, i);
      if (mrb_string_p(line)) {
        console_printf("  %s\n", RSTRING_CSTR(mrb, line));
      }
    }
  }
  console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
  mrb->exc = NULL;
}

static void print_diagnostics(mrc_ccontext *cc)
{
  console_set_colour(CONSOLE_RED, CONSOLE_BLACK);
  for (mrc_diagnostic_list *d = cc->diagnostic_list; d; d = d->next) {
    if (d->code == MRC_PARSER_ERROR || d->code == MRC_GENERATOR_ERROR) {
      console_printf("script:%d:%d: %s\n", (int)d->line, (int)d->column, d->message);
    }
  }
  console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
}

/* Fetch the script from the data slot; halts with a message when there is none. */
static size_t load_script(void)
{
  size_t len = 0;
  uint32_t code = 0;
  bridge_result_t r = bridge_read_file(SCRIPT_SLOT, script_buf, SCRIPT_MAX_SIZE, &len, &code);
  switch (r) {
  case BRIDGE_OK:
    console_set_colour(CONSOLE_GREY, CONSOLE_BLACK);
    console_printf("script: %u bytes\n", (unsigned)len);
    console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
    return len;
  case BRIDGE_NO_FILE:
    console_puts("No script loaded.\nPick a .rb file in the Script slot\nfrom the Pocket menu.\n");
    break;
  case BRIDGE_TOO_LARGE:
    console_printf("Script is larger than %u KB.\n", (unsigned)(SCRIPT_MAX_SIZE / 1024));
    break;
  case BRIDGE_TIMEOUT:
    console_puts("Timed out reading the script slot.\n");
    break;
  case BRIDGE_ERROR:
    console_printf("Reading the script slot failed (result code %lu).\n", (unsigned long)code);
    break;
  }
  halt();
  return 0;
}

int main(void)
{
  display_init();
  console_init();
  timer_init();

  console_set_colour(CONSOLE_GREEN, CONSOLE_BLACK);
  console_puts("PicoRuby on Analogue Pocket\n");
  console_set_colour(CONSOLE_GREY, CONSOLE_BLACK);
  console_printf("heap %u KB at %08lx\n", (unsigned)(RUBY_HEAP_SIZE / 1024), (unsigned long)RUBY_HEAP_BASE);
  console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);

  size_t script_len = load_script();

  mrb_state *mrb = mrb_open_with_custom_alloc((void *)RUBY_HEAP_BASE, RUBY_HEAP_SIZE);
  if (mrb == NULL) {
    console_puts("mrb_open_with_custom_alloc failed\n");
    halt();
  }
  global_mrb = mrb;
  if (mrb->exc) {
    console_puts("VM initialization raised:\n");
    print_exception(mrb, mrb_obj_value(mrb->exc));
    halt();
  }

  mrc_ccontext *cc = mrc_ccontext_new(mrb);
  mrc_ccontext_filename(cc, "script");
  const uint8_t *source = script_buf;
  mrc_irep *irep = mrc_load_string_cxt(cc, &source, script_len);
  if (irep == NULL) {
    console_puts("compile error:\n");
    print_diagnostics(cc);
    halt();
  }

  mrb_value name = mrb_str_new_lit(mrb, "main");
  mrb_value task = mrc_create_task(cc, irep, name, mrb_nil_value(), mrb_obj_value(mrb->top_self));
  if (mrb_nil_p(task)) {
    console_puts("mrc_create_task failed\n");
    halt();
  }

  mrb_task_run(mrb);

  if (mrb->exc) {
    console_puts("scheduler raised:\n");
    print_exception(mrb, mrb_obj_value(mrb->exc));
  }
  mrb_value result = mrb_task_value(mrb, task);
  if (mrb_exception_p(result)) {
    console_puts("main task raised:\n");
    print_exception(mrb, result);
  }
  halt();
  return 0;
}
