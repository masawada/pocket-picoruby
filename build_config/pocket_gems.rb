# Gems shared by the Pocket build and the browser build, so a script that runs
# in one runs in the other. Loaded by pocket-picoruby.rb and pocket-wasm.rb.

POCKET_GEM_DIR = File.expand_path("../gems/picoruby-pocket", __dir__)

def pocket_common_gems(conf)
  mruby_gems = "#{MRUBY_ROOT}/mrbgems/picoruby-mruby/lib/mruby/mrbgems"

  conf.gem core: "mruby-compiler"
  conf.gem core: "picoruby-mruby"
  conf.gem core: "picoruby-machine"

  # Core class extensions (String#start_with?, Array#sample, Integer#clamp, ...)
  %w[
    mruby-string-ext mruby-array-ext mruby-hash-ext mruby-enum-ext mruby-range-ext
    mruby-numeric-ext mruby-kernel-ext mruby-object-ext mruby-struct
    mruby-sprintf mruby-math mruby-random mruby-metaprog mruby-error
  ].each do |name|
    conf.gem gemdir: "#{mruby_gems}/#{name}"
  end

  conf.gem gemdir: POCKET_GEM_DIR
end
