# Firmware for the openfpga-litex SoC (VexRiscv SMP, rv32imafdc / ilp32d).
#
# Toolchain: xPack riscv-none-elf-gcc in .toolchain/ (scripts/fetch-toolchain.sh).
# Headers:   generated CSR/SoC headers committed in vendor/openfpga-litex.
# libc:      newlib (nano) from the toolchain; LiteX's picolibc is not used.
# Ruby VM:   libmruby.a from scripts/build-picoruby.sh (vendor/picoruby).

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
LITEX_DIR ?= $(ROOT)/vendor/openfpga-litex
PICORUBY_DIR ?= $(ROOT)/vendor/picoruby
TOOLCHAIN_DIR ?= $(ROOT)/.toolchain/xpack-riscv-none-elf-gcc-15.2.0-1
CROSS     ?= $(TOOLCHAIN_DIR)/bin/riscv-none-elf-

CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
SIZE    := $(CROSS)size

BUILD   := build
TARGET  := $(BUILD)/boot

ARCH_FLAGS := -march=rv32imafdc_zicsr -mabi=ilp32d

# --- PicoRuby -----------------------------------------------------------------
# Must match firmware/build_config/pocket-picoruby.rb (and what conf.picoruby /
# picoruby-mruby add on top of it): these fix sizeof(mrb_value) and the
# mrb_state layout shared with libmruby.a.
PICORUBY_BUILD := $(PICORUBY_DIR)/build/pocket-picoruby
LIBMRUBY := $(PICORUBY_BUILD)/lib/libmruby.a
PICORUBY_DEFINES := \
	-DPICORB_PLATFORM_POCKET \
	-DPICORB_VM_MRUBY -DMRB_USE_TASK_SCHEDULER \
	-DMRB_INT32 -DMRB_WORD_BOXING -DMRB_32BIT -DMRB_UTF8_STRING \
	-DMRB_CONSTRAINED_BASELINE_PROFILE=1 \
	-DPICORB_ALLOC_ESTALLOC -DPICORB_ALLOC_ALIGN=8 \
	-DMRB_TICK_UNIT=1 -DMRB_TIMESLICE_TICK_COUNT=10 \
	-DNO_CLOCK_GETTIME=1
PICORUBY_INCLUDES := \
	-I$(PICORUBY_DIR)/include \
	-I$(PICORUBY_DIR)/mrbgems/mruby-compiler/include \
	-I$(PICORUBY_DIR)/mrbgems/mruby-compiler/lib/prism/include \
	-I$(PICORUBY_DIR)/build/prism/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-mruby/lib/mruby/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-machine/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-mruby/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-task/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-require/include \
	-I$(PICORUBY_DIR)/mrbgems/picoruby-io-console/include \
	-I$(PICORUBY_BUILD)/include

# Gem port sources that the firmware compiles itself (a cross build adds none).
PORT_SRCS := $(PICORUBY_DIR)/mrbgems/picoruby-machine/ports/common/machine.c
PORT_OBJS := $(BUILD)/port_machine_common.o

FONT_BDF := $(PICORUBY_DIR)/mrbgems/picoruby-shinonome/lib/shinonome-0.9.11/bdf/shnm8x16a.bdf
FONT_H   := $(BUILD)/font_8x16.h

INCLUDES := \
	-I$(LITEX_DIR)/litex/build/litex/software/include \
	-I$(LITEX_DIR)/litex/vendor/litex/litex/soc/software/include \
	-I$(LITEX_DIR)/litex/vendor/litex/litex/soc/cores/cpu/vexriscv_smp \
	-Isrc -I$(BUILD) \
	$(PICORUBY_INCLUDES)

CFLAGS := $(ARCH_FLAGS) -Os -g -std=gnu11 -Wall -Wextra -Wno-unused-parameter \
	-ffunction-sections -fdata-sections -fno-strict-aliasing \
	$(PICORUBY_DEFINES) $(INCLUDES)

LINKER_DIR := $(LITEX_DIR)/lang/linker
LDFLAGS := $(ARCH_FLAGS) -nostartfiles --specs=nano.specs --specs=nosys.specs \
	-L$(LINKER_DIR) -T $(LINKER_DIR)/c-linker.ld \
	-Wl,--gc-sections -Wl,-Map,$(TARGET).map
LDLIBS := -L$(PICORUBY_BUILD)/lib -lmruby -lm

# init_asm.o must keep this name: c-linker.ld places *init_asm* first in .text.
OBJS := $(BUILD)/init_asm.o \
	$(BUILD)/main.o $(BUILD)/display.o $(BUILD)/console.o $(BUILD)/timer.o \
	$(BUILD)/hal_pocket.o $(BUILD)/newlib_stubs.o \
	$(PORT_OBJS)

.PHONY: all clean size
all: $(TARGET).bin size

$(BUILD):
	mkdir -p $(BUILD)

$(FONT_H): $(FONT_BDF) tools/bdf2c.rb | $(BUILD)
	ruby tools/bdf2c.rb $< $@

$(BUILD)/console.o: $(FONT_H)

$(BUILD)/init_asm.o: $(LINKER_DIR)/init_asm.S | $(BUILD)
	$(CC) $(ARCH_FLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD)/port_machine_common.o: $(PORT_SRCS) | $(BUILD)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(LIBMRUBY):
	@echo "$(LIBMRUBY) not found: run scripts/build-picoruby.sh" >&2; exit 1

$(TARGET).elf: $(OBJS) $(LIBMRUBY)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(TARGET).elf
	$(SIZE) $<

clean:
	rm -rf $(BUILD)

-include $(OBJS:.o=.d)
