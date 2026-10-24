/*
 * RISC-V machine-mode CSR access and the VexRiscv SMP CLINT register map.
 */
#ifndef POCKET_RISCV_H
#define POCKET_RISCV_H

#include <stdint.h>

#include "litex.h"

#define csr_read(csr) ({ uint32_t v_; __asm__ volatile("csrr %0, " #csr : "=r"(v_)); v_; })
#define csr_write(csr, v) __asm__ volatile("csrw " #csr ", %0" : : "rK"((uint32_t)(v)))
#define csr_set(csr, v) __asm__ volatile("csrs " #csr ", %0" : : "rK"((uint32_t)(v)))
#define csr_clear(csr, v) __asm__ volatile("csrc " #csr ", %0" : : "rK"((uint32_t)(v)))

#define MSTATUS_MIE (1u << 3)
#define MIE_MTIE (1u << 7)
#define MCAUSE_INTERRUPT (1u << 31)
#define MCAUSE_MACHINE_TIMER 7u

static inline void wfi(void) { __asm__ volatile("wfi"); }

/* SiFive-compatible CLINT layout, hart 0 only. mtime counts system clocks. */
#define CLINT_MTIMECMP_LO (*(volatile uint32_t *)(CLINT_BASE + 0x4000))
#define CLINT_MTIMECMP_HI (*(volatile uint32_t *)(CLINT_BASE + 0x4004))
#define CLINT_MTIME_LO (*(volatile uint32_t *)(CLINT_BASE + 0xbff8))
#define CLINT_MTIME_HI (*(volatile uint32_t *)(CLINT_BASE + 0xbffc))

static inline uint64_t clint_mtime(void)
{
  uint32_t hi, lo;
  do {
    hi = CLINT_MTIME_HI;
    lo = CLINT_MTIME_LO;
  } while (hi != CLINT_MTIME_HI);
  return ((uint64_t)hi << 32) | lo;
}

static inline void clint_set_mtimecmp(uint64_t t)
{
  /* Never let the compare value pass through a small intermediate. */
  CLINT_MTIMECMP_HI = 0xffffffffu;
  CLINT_MTIMECMP_LO = (uint32_t)t;
  CLINT_MTIMECMP_HI = (uint32_t)(t >> 32);
}

#endif
