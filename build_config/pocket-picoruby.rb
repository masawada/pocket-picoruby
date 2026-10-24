# PicoRuby cross build for the openfpga-litex SoC on the Analogue Pocket
# (VexRiscv SMP, rv32imafdc / ilp32d, newlib).
#
# Run from vendor/picoruby:
#   MRUBY_CONFIG=/abs/path/to/this/file rake
# scripts/build-picoruby.sh wraps that.
#
# The defines that fix sizeof(mrb_value) and the mrb_state layout are mirrored
# in firmware/Makefile; the two must stay in sync or the firmware crashes in
# the first mrb_* call.

require_relative "pocket_gems"

TOOLCHAIN_BIN = ENV['POCKET_TOOLCHAIN_BIN'] ||
  File.expand_path("../.toolchain/xpack-riscv-none-elf-gcc-15.2.0-1/bin", __dir__)

MRuby::CrossBuild.new("pocket-picoruby#{ENV['PICORB_DEBUG'] ? '-debug' : ''}") do |conf|
  conf.toolchain :gcc

  conf.cc.command = "#{TOOLCHAIN_BIN}/riscv-none-elf-gcc"
  conf.linker.command = "#{TOOLCHAIN_BIN}/riscv-none-elf-gcc"
  conf.archiver.command = "#{TOOLCHAIN_BIN}/riscv-none-elf-ar"
  conf.cc.host_command = "gcc"

  conf.cc.defines << "PICORB_PLATFORM_POCKET"

  conf.cc.defines << "MRB_TICK_UNIT=1"
  conf.cc.defines << "MRB_TIMESLICE_TICK_COUNT=10"

  # 32-bit word boxing: mrb_value is 4 bytes.
  conf.cc.defines << "MRB_INT32"
  conf.cc.defines << "MRB_WORD_BOXING"
  conf.cc.defines << "MRB_32BIT"
  # picoruby-mruby adds this too, but too late for the mruby core sources;
  # without it here string.c lacks the UTF-8 helpers the ext gems reference.
  conf.cc.defines << "MRB_UTF8_STRING"
  conf.cc.defines << "NO_CLOCK_GETTIME=1"

  conf.cc.flags.flatten!
  conf.cc.flags << "-march=rv32imafdc_zicsr"
  conf.cc.flags << "-mabi=ilp32d"
  conf.cc.flags << "-fno-strict-aliasing"
  conf.cc.flags << "-Wall"
  conf.cc.flags << "-Wno-format"
  conf.cc.flags << "-Wno-unused-function"
  conf.cc.flags << "-ffunction-sections"
  conf.cc.flags << "-fdata-sections"
  conf.linker.flags << "-march=rv32imafdc_zicsr"
  conf.linker.flags << "-mabi=ilp32d"

  conf.picoruby

  pocket_common_gems(conf)

  # picoruby-mruby puts every non-POSIX target on MRB_CONSTRAINED_BASELINE_PROFILE,
  # which turns the method cache off (MRB_NO_METHOD_CACHE). That suits a
  # 264 KB microcontroller; here a method call costs ~80 us without the cache on
  # a 57 MHz core with 4 KB caches, and there is 40 MB of RAM. The gem adds the
  # define from its mrbgem.rake, so it is removed at the one point that runs
  # after every gem has contributed its defines. firmware/Makefile must not
  # define it either (it changes sizeof(mrb_state)).
  class << conf
    def defines_final!
      defines.delete("MRB_CONSTRAINED_BASELINE_PROFILE=1")
      super
    end
  end
end
