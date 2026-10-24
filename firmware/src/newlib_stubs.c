/*
 * The few newlib syscalls that matter here. Everything else comes from
 * --specs=nosys.specs and fails harmlessly.
 */
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#include "console.h"

/* The Ruby heap never touches libc malloc (Estalloc), so this strip only
 * serves newlib internals such as stdio buffers. */
#define LIBC_HEAP_SIZE (256 * 1024)
static uint8_t libc_heap[LIBC_HEAP_SIZE] __attribute__((aligned(16)));
static size_t libc_heap_used;

void *_sbrk(ptrdiff_t incr)
{
  if (incr < 0 || libc_heap_used + (size_t)incr > LIBC_HEAP_SIZE) {
    errno = ENOMEM;
    return (void *)-1;
  }
  void *prev = libc_heap + libc_heap_used;
  libc_heap_used += (size_t)incr;
  return prev;
}

/* printf and friends end up on the screen, stderr in red. */
ssize_t _write(int fd, const void *buf, size_t len)
{
  if (fd == 2) {
    console_set_colour(CONSOLE_RED, CONSOLE_BLACK);
    console_write(buf, len);
    console_set_colour(CONSOLE_WHITE, CONSOLE_BLACK);
  }
  else {
    console_write(buf, len);
  }
  return (ssize_t)len;
}
