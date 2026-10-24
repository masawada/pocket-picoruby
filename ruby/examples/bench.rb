# Rough speed figures for the VM and the drawing calls, printed on screen.
# Load it on the Pocket to see what a frame budget of 16 ms buys.

D = Pocket::Display

def bench(name)
  t0 = Machine.uptime_us
  yield
  puts "#{name}: #{(Machine.uptime_us - t0) / 1000} ms"
end

bench("100k empty loop") do
  i = 0
  i += 1 while i < 100_000
end

bench("10k method calls") do
  obj = Object.new
  def obj.m(a); a + 1; end
  i = 0
  i = obj.m(i) while i < 10_000
end

bench("10k array alloc") do
  i = 0
  while i < 10_000
    a = [i, i + 1]
    i += 1
  end
end

cells = Array.new(200, 1)
last = Array.new(200, 0)
bench("20x 200-cell diff") do
  20.times do
    i = 0
    while i < 200
      last[i] = cells[i] if cells[i] != last[i]
      i += 1
    end
  end
end

bench("1000 fill_rect 10x10") do
  i = 0
  while i < 1000
    D.fill_rect(30 + (i % 20) * 10, 120 + (i % 10) * 10, 10, 10, i)
    i += 1
  end
end

bench("100 draw_text 8 chars") do
  i = 0
  while i < 100
    D.draw_text(30, 100, "12345678", 0xffff, 0)
    i += 1
  end
end

bench("60x wait_vsync") do
  60.times { Pocket.wait_vsync }
end

bench("60x flush (full)") do
  60.times do
    D.fill_rect(0, 0, 1, 240, 0)
    D.flush
  end
end

bench("60x flush (40 rows)") do
  60.times do
    D.fill_rect(0, 100, 1, 40, 0)
    D.flush
  end
end

bench("60x sleep_ms 1") do
  60.times { sleep_ms 1 }
end

puts "done"
