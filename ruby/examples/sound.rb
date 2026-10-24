# Pocket::Audio demo: each button plays a different sound.
# (In the browser, press any key once first so the page may start audio.)

D = Pocket::Display
A = Pocket::Audio
I = Pocket::Input

D.clear(Pocket.rgb(10, 20, 30))
D.draw_text(8, 8, "Pocket::Audio demo", 0xffff)
D.draw_text(8, 32, "A  square blip", 0xffff)
D.draw_text(8, 48, "B  triangle, decaying", 0xffff)
D.draw_text(8, 64, "X  saw slide up", 0xffff)
D.draw_text(8, 80, "Y  noise burst", 0xffff)
D.draw_text(8, 96, "L/R  arpeggio / chord", 0xffff)
D.draw_text(8, 112, "Start  stop all", 0xffff)
D.flush

input = I::State.new
loop do
  input.update
  A.play(0, 880, 60) if input.pressed?(I::A)
  A.play(1, 440, 400, wave: :triangle, decay: true) if input.pressed?(I::B)
  A.play(2, 200, 300, wave: :saw, slide_to: 1600, volume: 100) if input.pressed?(I::X)
  A.play(3, 4000, 150, wave: :noise, decay: true) if input.pressed?(I::Y)
  if input.pressed?(I::L1)
    A.play(0, 523, 100)
    A.play(1, 659, 100)
    A.play(2, 784, 100)
    A.play(3, 1047, 100)
  end
  if input.pressed?(I::R1)
    A.play(0, 262, 600, volume: 90, wave: :triangle)
    A.play(1, 330, 600, volume: 90, wave: :triangle)
    A.play(2, 392, 600, volume: 90, wave: :triangle)
  end
  A.stop if input.pressed?(I::START)
  Pocket.wait_vsync
end
