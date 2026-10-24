#include "bridge.h"

#include "display.h"
#include "litex.h"
#include "riscv.h"

#define TRANSFER_TIMEOUT_US (5u * 1000 * 1000)

uint32_t bridge_file_size(uint16_t slot)
{
  apf_bridge_slot_id_write(slot);
  /* The size register follows the slot change a few cycles later. */
  (void)apf_bridge_slot_id_read();
  return apf_bridge_file_size_read();
}

bridge_result_t bridge_read_file(uint16_t slot, void *buf, size_t cap, size_t *len, uint32_t *code)
{
  uint32_t size = bridge_file_size(slot);
  if (size == 0 || size == 0xffffffffu) {
    return BRIDGE_NO_FILE;
  }
  if (size > cap) {
    return BRIDGE_TOO_LARGE;
  }

  /* The bridge writes straight into SDRAM: push out any dirty cache lines for
   * the buffer first, and drop stale ones once the transfer is done. */
  display_flush();

  /* A completed transfer (the boot.bin load at power-up, say) leaves status at
   * 1 until it is read; clear it so the wait below sees this request only. */
  (void)apf_bridge_status_read();

  apf_bridge_data_offset_write(0);
  apf_bridge_transfer_length_write(size);
  apf_bridge_ram_data_address_write((uint32_t)(uintptr_t)buf);
  apf_bridge_slot_id_write(slot);
  apf_bridge_request_read_write(1);

  /* status reads 1 once the transfer has completed (and clears on read). */
  uint64_t deadline = clint_mtime() + (uint64_t)TRANSFER_TIMEOUT_US * CONFIG_CLOCK_FREQUENCY / 1000000u;
  while (apf_bridge_status_read() != 1) {
    if (clint_mtime() > deadline) {
      return BRIDGE_TIMEOUT;
    }
  }
  display_flush();

  uint32_t result = apf_bridge_command_result_code_read();
  if (result != 0) {
    *code = result;
    return BRIDGE_ERROR;
  }
  *len = size;
  return BRIDGE_OK;
}
