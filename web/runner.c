/*
 * Browser host for PicoRuby: the counterpart of firmware/src/main.c.
 *
 * JavaScript (web/runner.js) calls, in order: pocket_wasm_init(), then
 * pocket_wasm_load(code, filename) for the script, then on a timer
 * pocket_wasm_tick() every MRB_TICK_UNIT ms and pocket_wasm_step() until it
 * reports idle. Output goes to stdout/stderr (Module.print / printErr).
 */
#include <emscripten/emscripten.h>
#include <stdio.h>
#include <string.h>

#include "picoruby.h"
#include <task.h>
#include <mruby/internal.h>
#include <mruby/string.h>

extern mrb_state *global_mrb; /* defined in mruby-compiler (ccontext.c) */

static void print_exception(mrb_state *mrb, mrb_value exc)
{
  mrb->exc = NULL;
  mrb_value msg = mrb_funcall(mrb, exc, "message", 0);
  mrb->exc = NULL;
  fprintf(stderr, "%s: %s\n", mrb_obj_classname(mrb, exc),
          mrb_string_p(msg) ? RSTRING_CSTR(mrb, msg) : "(no message)");
  mrb_value bt = mrb_exc_backtrace(mrb, exc);
  if (mrb_array_p(bt)) {
    for (mrb_int i = 0; i < RARRAY_LEN(bt); i++) {
      mrb_value line = mrb_ary_ref(mrb, bt, i);
      if (mrb_string_p(line)) {
        fprintf(stderr, "  %s\n", RSTRING_CSTR(mrb, line));
      }
    }
  }
  mrb->exc = NULL;
}

EMSCRIPTEN_KEEPALIVE int pocket_wasm_init(void)
{
  mrb_state *mrb = mrb_open();
  if (mrb == NULL) {
    fprintf(stderr, "mrb_open failed\n");
    return -1;
  }
  global_mrb = mrb;
  if (mrb->exc) {
    fprintf(stderr, "VM initialization raised:\n");
    print_exception(mrb, mrb_obj_value(mrb->exc));
    return -1;
  }
  mrb_gc_scheduler_driven(mrb, TRUE);
  return 0;
}

/* Compile the script and queue it as a task. Returns 0 on success. */
EMSCRIPTEN_KEEPALIVE int pocket_wasm_load(const char *code, const char *filename)
{
  mrb_state *mrb = global_mrb;
  if (mrb == NULL) return -1;

  mrc_ccontext *cc = mrc_ccontext_new(mrb);
  mrc_ccontext_filename(cc, filename && *filename ? filename : "script");
  const uint8_t *source = (const uint8_t *)code;
  mrc_irep *irep = mrc_load_string_cxt(cc, &source, strlen(code));
  if (irep == NULL) {
    for (mrc_diagnostic_list *d = cc->diagnostic_list; d; d = d->next) {
      if (d->code == MRC_PARSER_ERROR || d->code == MRC_GENERATOR_ERROR) {
        fprintf(stderr, "%s:%d:%d: %s\n", filename, (int)d->line, (int)d->column, d->message);
      }
    }
    mrc_ccontext_free(cc);
    return -1;
  }

  mrb_value name = mrb_str_new_cstr(mrb, filename ? filename : "main");
  mrb_value task = mrc_create_task(cc, irep, name, mrb_nil_value(), mrb_obj_value(mrb->top_self));
  mrc_ccontext_free(cc);
  if (mrb_nil_p(task)) {
    fprintf(stderr, "mrc_create_task failed\n");
    return -1;
  }
  return 0;
}

EMSCRIPTEN_KEEPALIVE void pocket_wasm_tick(void)
{
  if (global_mrb) mrb_tick(global_mrb);
}

/* 1 while any task is ready, sleeping or suspended; 0 once every task ended. */
EMSCRIPTEN_KEEPALIVE int pocket_wasm_alive(void)
{
  mrb_state *mrb = global_mrb;
  if (mrb == NULL) return 0;
  return (q_ready_ != NULL || q_waiting_ != NULL || q_suspended_ != NULL) ? 1 : 0;
}

/* Run one scheduler step. 1 = made progress, 0 = idle, 2 = a task raised. */
EMSCRIPTEN_KEEPALIVE int pocket_wasm_step(void)
{
  mrb_state *mrb = global_mrb;
  if (mrb == NULL) return -1;

  mrb_bool had_ready = (q_ready_ != NULL);
  mrb_bool had_gc = mrb_gc_scheduler_pending(mrb);
  mrb_value result = mrb_task_run_once(mrb);

  if (mrb->exc) {
    print_exception(mrb, mrb_obj_value(mrb->exc));
    return 2;
  }
  if (mrb_exception_p(result)) {
    print_exception(mrb, result);
    return 2;
  }
  return (had_ready || had_gc || !mrb_nil_p(result)) ? 1 : 0;
}
