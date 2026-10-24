#!/usr/bin/env ruby
# Run test/*_test.rb on the wasm build. Picotest orchestrates from CRuby and
# executes each test class on PicoRuby through scripts/run-rb.mjs (node).
#
#   ruby scripts/test.rb            # everything under test/
#   ruby scripts/test.rb board      # only files whose name includes "board"
#
# Needs web/dist/pocket-node.js (scripts/build-wasm.sh). Files under ruby/lib/
# are embedded before each test, so game code is tested without a loader.

ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "vendor/picoruby/mrbgems/picoruby-picotest/mrblib")
require "picotest"

ENV["RUBY"] = "node #{File.join(ROOT, 'scripts/run-rb.mjs')}"

runner = Picotest::Runner.new(
  File.join(ROOT, "test"),
  filter: ARGV[0],
  tmpdir: ENV["TMPDIR"] || "/tmp",
  load_files: Dir[File.join(ROOT, "ruby/lib/**/*.rb")].sort
)
exit(runner.run.to_i == 0 ? 0 : 1)
