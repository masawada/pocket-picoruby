# Default script, loaded from the "Script" slot at boot.
# Replace it from the Pocket's core menu with any .rb on the SD card.

puts "Hello from main.rb on the Pocket!"
puts "#{RUBY_ENGINE} #{RUBY_VERSION}, uptime #{Machine.uptime_us / 1000} ms"

count = 0
loop do
  puts "alive #{count}"
  count += 1
  sleep 1
end
