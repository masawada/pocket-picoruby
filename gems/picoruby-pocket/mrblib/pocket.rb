module Pocket
  # RGB565 from 8-bit components.
  def self.rgb(r, g, b)
    ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
  end

  # Returns once the next vertical blank has started. Draw, then call this,
  # then flush: the same loop runs on the Pocket and in the browser runner.
  def self.wait_vsync
    sleep_ms 1 until _vblank?
  end

  module Input
    UP     = 1 << 0
    DOWN   = 1 << 1
    LEFT   = 1 << 2
    RIGHT  = 1 << 3
    A      = 1 << 4
    B      = 1 << 5
    X      = 1 << 6
    Y      = 1 << 7
    L1     = 1 << 8
    R1     = 1 << 9
    L2     = 1 << 10
    R2     = 1 << 11
    L3     = 1 << 12
    R3     = 1 << 13
    SELECT = 1 << 14
    START  = 1 << 15

    # Tracks the previous read so callers get edge detection for free.
    class State
      attr_reader :held, :previous

      def initialize
        @held = 0
        @previous = 0
      end

      def update
        @previous = @held
        @held = Input.read
        self
      end

      def held?(mask)
        (@held & mask) != 0
      end

      def pressed?(mask)
        (@held & ~@previous & mask) != 0
      end

      def released?(mask)
        (~@held & @previous & mask) != 0
      end
    end
  end
end
