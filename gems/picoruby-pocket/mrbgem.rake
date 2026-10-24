MRuby::Gem::Specification.new('picoruby-pocket') do |spec|
  spec.license = 'MIT'
  spec.author  = 'masawada'
  spec.summary = 'Analogue Pocket display and input for PicoRuby'

  spec.add_dependency 'picoruby-machine'

  # The 8x16 ASCII font (Shinonome, public domain) is converted into a C header
  # at build time; src/fb.c draws text with it.
  include_dir = "#{build_dir}/include"
  spec.cc.include_paths << include_dir
  font_bdf = "#{MRUBY_ROOT}/mrbgems/picoruby-shinonome/lib/shinonome-0.9.11/bdf/shnm8x16a.bdf"
  font_tool = "#{dir}/tools/bdf2c.rb"
  font_h = "#{include_dir}/font_8x16.h"
  if !File.exist?(font_h) || File.mtime(font_h) < [File.mtime(font_bdf), File.mtime(font_tool)].max
    FileUtils.mkdir_p(include_dir)
    sh "ruby #{font_tool} #{font_bdf} #{font_h}"
  end
end
