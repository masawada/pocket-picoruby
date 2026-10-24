#include "mruby.h"
#include "mruby/presym.h"
#include "mruby/string.h"

/*
 * Pocket::Display.clear(colour = 0)
 * Pocket::Display.fill_rect(x, y, w, h, colour)
 * Pocket::Display.draw_text(x, y, str, colour, bg = nil)
 * Pocket::Display.flush
 * Pocket._vblank?          # Pocket.wait_vsync in mrblib polls this
 * Pocket.frame_count
 * Pocket::Input.read       # raw button bitmap
 *
 * Colours are RGB565 Integers; see Pocket.rgb in mrblib.
 */

static uint16_t to_colour(mrb_state *mrb, mrb_int c)
{
  if (c < 0 || c > 0xffff) {
    mrb_raise(mrb, E_ARGUMENT_ERROR, "colour must be an RGB565 value (0..0xffff)");
  }
  return (uint16_t)c;
}

static mrb_value display_clear(mrb_state *mrb, mrb_value klass)
{
  mrb_int colour = 0;
  mrb_get_args(mrb, "|i", &colour);
  pocket_fb_fill_rect(pocket_port_framebuffer(), 0, 0, POCKET_WIDTH, POCKET_HEIGHT, to_colour(mrb, colour));
  return mrb_nil_value();
}

static mrb_value display_fill_rect(mrb_state *mrb, mrb_value klass)
{
  mrb_int x, y, w, h, colour;
  mrb_get_args(mrb, "iiiii", &x, &y, &w, &h, &colour);
  pocket_fb_fill_rect(pocket_port_framebuffer(), (int)x, (int)y, (int)w, (int)h, to_colour(mrb, colour));
  return mrb_nil_value();
}

static mrb_value display_draw_text(mrb_state *mrb, mrb_value klass)
{
  mrb_int x, y, fg;
  mrb_value str, bg = mrb_nil_value();
  mrb_get_args(mrb, "iiSi|o", &x, &y, &str, &fg, &bg);
  int bg_colour = -1;
  if (!mrb_nil_p(bg)) {
    bg_colour = to_colour(mrb, mrb_as_int(mrb, bg));
  }
  pocket_fb_draw_text(pocket_port_framebuffer(), (int)x, (int)y, RSTRING_PTR(str), (size_t)RSTRING_LEN(str),
                      to_colour(mrb, fg), bg_colour);
  return mrb_nil_value();
}

static mrb_value display_flush(mrb_state *mrb, mrb_value klass)
{
  pocket_port_flush();
  return mrb_nil_value();
}

static mrb_value pocket_vblank_p(mrb_state *mrb, mrb_value klass)
{
  return mrb_bool_value(pocket_port_vblank_triggered());
}

static mrb_value pocket_wait_vblank(mrb_state *mrb, mrb_value klass)
{
  return mrb_bool_value(pocket_port_wait_vblank());
}

static mrb_value pocket_frame_count(mrb_state *mrb, mrb_value klass)
{
  return mrb_int_value(mrb, (mrb_int)(pocket_port_frame_count() & 0x3fffffff));
}

static mrb_value input_read(mrb_state *mrb, mrb_value klass)
{
  return mrb_int_value(mrb, (mrb_int)(pocket_port_keys() & 0xffff));
}

void mrb_picoruby_pocket_gem_init(mrb_state *mrb)
{
  struct RClass *pocket = mrb_define_module_id(mrb, MRB_SYM(Pocket));
  mrb_define_class_method_id(mrb, pocket, MRB_SYM_Q(_vblank), pocket_vblank_p, MRB_ARGS_NONE());
  mrb_define_class_method_id(mrb, pocket, MRB_SYM(_wait_vblank), pocket_wait_vblank, MRB_ARGS_NONE());
  mrb_define_class_method_id(mrb, pocket, MRB_SYM(frame_count), pocket_frame_count, MRB_ARGS_NONE());

  struct RClass *display = mrb_define_module_under_id(mrb, pocket, MRB_SYM(Display));
  mrb_define_const_id(mrb, display, MRB_SYM(WIDTH), mrb_fixnum_value(POCKET_WIDTH));
  mrb_define_const_id(mrb, display, MRB_SYM(HEIGHT), mrb_fixnum_value(POCKET_HEIGHT));
  mrb_define_const_id(mrb, display, MRB_SYM(FONT_WIDTH), mrb_fixnum_value(POCKET_FONT_WIDTH));
  mrb_define_const_id(mrb, display, MRB_SYM(FONT_HEIGHT), mrb_fixnum_value(POCKET_FONT_HEIGHT));
  mrb_define_class_method_id(mrb, display, MRB_SYM(clear), display_clear, MRB_ARGS_OPT(1));
  mrb_define_class_method_id(mrb, display, MRB_SYM(fill_rect), display_fill_rect, MRB_ARGS_REQ(5));
  mrb_define_class_method_id(mrb, display, MRB_SYM(draw_text), display_draw_text, MRB_ARGS_ARG(4, 1));
  mrb_define_class_method_id(mrb, display, MRB_SYM(flush), display_flush, MRB_ARGS_NONE());

  struct RClass *input = mrb_define_module_under_id(mrb, pocket, MRB_SYM(Input));
  mrb_define_class_method_id(mrb, input, MRB_SYM(read), input_read, MRB_ARGS_NONE());
}

void mrb_picoruby_pocket_gem_final(mrb_state *mrb)
{
}
