/*
 * Analogue Pocket File API through the openfpga-litex bridge CSRs
 * (vendor/openfpga-litex/docs/control.md, "Bridge").
 */
#ifndef POCKET_BRIDGE_H
#define POCKET_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
  BRIDGE_OK = 0,
  BRIDGE_NO_FILE,    /* the slot has no file, or it is empty */
  BRIDGE_TOO_LARGE,  /* the file does not fit in the buffer */
  BRIDGE_TIMEOUT,    /* the transfer never completed */
  BRIDGE_ERROR,      /* the Pocket reported a command result code; see *code */
} bridge_result_t;

/* Size on disk of the file in a data.json slot. */
uint32_t bridge_file_size(uint16_t slot);

/*
 * Read the whole file in a slot into buf. On BRIDGE_OK *len is the byte count;
 * on BRIDGE_ERROR *code is the Pocket's command result code.
 */
bridge_result_t bridge_read_file(uint16_t slot, void *buf, size_t cap, size_t *len, uint32_t *code);

#endif
