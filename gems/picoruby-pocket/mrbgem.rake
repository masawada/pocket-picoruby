MRuby::Gem::Specification.new('picoruby-pocket') do |spec|
  spec.license = 'MIT'
  spec.author  = 'masawada'
  spec.summary = 'Analogue Pocket display and input for PicoRuby'

  spec.add_dependency 'picoruby-machine'

  # The Shinonome fonts (public domain) are converted into C headers at build
  # time; src/fb.c draws text with them: 8x16 for ASCII, 16x16 for JIS X 0208.
  include_dir = "#{build_dir}/include"
  spec.cc.include_paths << include_dir
  shinonome = "#{MRUBY_ROOT}/mrbgems/picoruby-shinonome/lib"
  fonts = [
    { tool: "#{dir}/tools/bdf2c.rb", out: "#{include_dir}/font_8x16.h",
      inputs: ["#{shinonome}/shinonome-0.9.11/bdf/shnm8x16a.bdf"] },
    { tool: "#{dir}/tools/jisfont2c.rb", out: "#{include_dir}/font_jis16.h",
      inputs: ["#{shinonome}/shinonome-0.9.11/bdf/shnmk16.bdf", "#{shinonome}/JIS0208.TXT"] },
  ]
  fonts.each do |font|
    sources = font[:inputs] + [font[:tool]]
    next if File.exist?(font[:out]) && File.mtime(font[:out]) >= sources.map { |s| File.mtime(s) }.max
    FileUtils.mkdir_p(include_dir)
    sh "ruby #{font[:tool]} #{font[:inputs].join(' ')} #{font[:out]}"
  end
end
