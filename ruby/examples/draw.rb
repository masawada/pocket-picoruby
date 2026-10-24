# Exercises the Pocket gem: rectangles, text, vsync pacing and the gamepad.
# A box moves with the d-pad; A/B change its colour; the frame counter and the
# raw button bitmap are printed at the bottom.

D = Pocket::Display
I = Pocket::Input

BG = Pocket.rgb(16, 24, 48)
WHITE = Pocket.rgb(255, 255, 255)
GREY = Pocket.rgb(128, 128, 128)
COLOURS = [Pocket.rgb(255, 80, 80), Pocket.rgb(80, 255, 80), Pocket.rgb(80, 120, 255), Pocket.rgb(255, 220, 60)]

D.clear(BG)
D.draw_text(8, 8, "pocket-picoruby draw test", WHITE)
D.draw_text(8, 24, "d-pad: move  A/B: colour", GREY)
D.flush

x = 120
y = 100
colour = 0
input = I::State.new
t0 = Machine.uptime_us

loop do
  input.update
  x -= 2 if input.held?(I::LEFT)
  x += 2 if input.held?(I::RIGHT)
  y -= 2 if input.held?(I::UP)
  y += 2 if input.held?(I::DOWN)
  colour = (colour + 1) % COLOURS.size if input.pressed?(I::A)
  colour = (colour - 1) % COLOURS.size if input.pressed?(I::B)

  D.fill_rect(0, 48, D::WIDTH, D::HEIGHT - 48 - 20, BG)
  D.fill_rect(x, y, 24, 24, COLOURS[colour])
  elapsed_ms = (Machine.uptime_us - t0) / 1000
  D.draw_text(8, D::HEIGHT - 18, "frame #{Pocket.frame_count}  keys #{input.held.to_s(16)}  #{elapsed_ms / 1000}s", GREY, BG)

  Pocket.wait_vsync
  D.flush
end
