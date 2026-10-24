/*
 * M2: boot PicoRuby, compile an embedded script on the device and run it.
 * Output and exceptions appear on the on-screen console.
 */
#include <stdint.h>
#include <string.h>

#include "picoruby.h"
#include <task.h>
#include <mruby/internal.h>
#include <mruby/string.h>
#include "hal.h"

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

extern mrb_state *global_mrb; /* defined in mruby-compiler (ccontext.c) */

static const char main_script[] =
  "puts 'Hello from PicoRuby on the Pocket!'\n"
  "puts \"RUBY_ENGINE=#{RUBY_ENGINE} #{RUBY_VERSION}\"\n"
  "puts \"platform: #{Machine.respond_to?(:uptime_us) ? 'Machine ok' : 'Machine?'}\"\n"
  "5.times do |i|\n"
  "  puts \"tick #{i} at #{Machine.uptime_us / 1000} ms\"\n"
  "  sleep 0.5\n"
  "end\n"
  "def boom(n)\n"
  "  raise ArgumentError, 'boom' if n == 0\n"
  "  boom(n - 1)\n"
  "end\n"
  "boom(3)\n";

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
      console_printf("main.rb:%d:%d: %s\n", (int)d->line, (int)d->column, d->message);
    }
  }
  console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
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
  mrc_ccontext_filename(cc, "main.rb");
  const uint8_t *source = (const uint8_t *)main_script;
  mrc_irep *irep = mrc_load_string_cxt(cc, &source, strlen(main_script));
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
