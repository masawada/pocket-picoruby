# Smallest script: prints and exits. Handy for scripts/run-rb.ts.
puts "hello from #{RUBY_ENGINE} #{RUBY_VERSION}"
puts "screen #{Pocket::Display::WIDTH}x#{Pocket::Display::HEIGHT}, rand #{rand(100)}"
