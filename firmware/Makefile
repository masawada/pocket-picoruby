# Firmware for the openfpga-litex SoC (VexRiscv SMP, rv32imafdc / ilp32d).
#
# Toolchain: xPack riscv-none-elf-gcc in .toolchain/ (scripts/fetch-toolchain.sh).
# Headers:   generated CSR/SoC headers committed in vendor/openfpga-litex.
# libc:      newlib (nano) from the toolchain; LiteX's picolibc is not used.

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
LITEX_DIR ?= $(ROOT)/vendor/openfpga-litex
TOOLCHAIN_DIR ?= $(ROOT)/.toolchain/xpack-riscv-none-elf-gcc-15.2.0-1
CROSS     ?= $(TOOLCHAIN_DIR)/bin/riscv-none-elf-

CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
SIZE    := $(CROSS)size

BUILD   := build
TARGET  := $(BUILD)/boot

ARCH_FLAGS := -march=rv32imafdc_zicsr -mabi=ilp32d

INCLUDES := \
	-I$(LITEX_DIR)/litex/build/litex/software/include \
	-I$(LITEX_DIR)/litex/vendor/litex/litex/soc/software/include \
	-I$(LITEX_DIR)/litex/vendor/litex/litex/soc/cores/cpu/vexriscv_smp \
	-Isrc

CFLAGS := $(ARCH_FLAGS) -Os -g -std=gnu11 -Wall -Wextra \
	-ffunction-sections -fdata-sections -fno-strict-aliasing \
	$(INCLUDES)

LINKER_DIR := $(LITEX_DIR)/lang/linker
LDFLAGS := $(ARCH_FLAGS) -nostartfiles --specs=nano.specs --specs=nosys.specs \
	-L$(LINKER_DIR) -T $(LINKER_DIR)/c-linker.ld \
	-Wl,--gc-sections -Wl,-Map,$(TARGET).map

# init_asm.o must keep this name: c-linker.ld places *init_asm* first in .text.
OBJS := $(BUILD)/init_asm.o $(BUILD)/main.o

.PHONY: all clean size
all: $(TARGET).bin size

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/init_asm.o: $(LINKER_DIR)/init_asm.S | $(BUILD)
	$(CC) $(ARCH_FLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(TARGET).elf: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(TARGET).elf
	$(SIZE) $<

clean:
	rm -rf $(BUILD)

-include $(OBJS:.o=.d)
