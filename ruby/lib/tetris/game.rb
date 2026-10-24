module Tetris
  # Game rules, advanced one frame at a time by #update with an input that
  # exposes the Pocket::Input bitmaps as `held` and `previous`.
  # Nothing here draws; tetris_main.rb renders the state.
  class Game
    SPAWN_X = 3
    SPAWN_Y = 0
    DAS_DELAY = 10      # frames a direction is held before auto-repeat
    DAS_REPEAT = 4      # frames between auto-repeated moves
    LOCK_DELAY = 30     # frames a grounded piece may still move before locking
    LOCK_RESETS = 8     # how many moves/rotations may restart the lock delay
    SOFT_DROP_FRAMES = 2
    LINE_SCORES = [0, 100, 300, 500, 800]
    GRAVITY = [48, 43, 38, 33, 28, 23, 18, 13, 8, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2]
    KICKS = [[0, 0], [-1, 0], [1, 0], [-2, 0], [2, 0], [0, -1]]

    attr_reader :board, :current, :score, :lines, :level
    # version changes whenever the falling piece or the well changes, so a
    # renderer can skip frames where nothing moved (most of them at low
    # levels); board_version changes only when the well itself does (a lock
    # or a restart). last_cleared is the line count of the latest lock, so a
    # renderer knows whether rows shifted.
    attr_reader :version, :board_version, :last_cleared

    # bag: callable returning the next 7 kinds (a shuffled Piece::KINDS by default).
    def initialize(bag: nil)
      @bag = bag || ->(kinds) { kinds.shuffle }
      @board = Board.new
      restart
    end

    def restart
      @board.clear
      @queue = []
      @score = 0
      @lines = 0
      @level = 1
      @over = false
      @version = (@version || 0) + 1
      @board_version = (@board_version || 0) + 1
      @last_cleared = 0
      @das_dir = 0
      @das_frames = 0
      spawn
    end

    def over?
      @over
    end

    def next_kind
      @queue[0]
    end

    def self.level_for(lines)
      1 + lines / 10
    end

    def self.gravity_frames(level)
      GRAVITY[[level - 1, GRAVITY.size - 1].min]
    end

    # Where the current piece would land; used for the ghost outline.
    def ghost
      @current.moved(0, @board.drop_distance(@current))
    end

    def update(input)
      held = input.held
      pressed = held & ~input.previous

      if @over
        restart if (pressed & Pocket::Input::START) != 0
        return
      end

      handle_horizontal(held)
      try_rotate(1) if (pressed & Pocket::Input::A) != 0
      try_rotate(-1) if (pressed & Pocket::Input::B) != 0

      if (pressed & Pocket::Input::UP) != 0
        hard_drop
        return
      end

      apply_gravity((held & Pocket::Input::DOWN) != 0)
    end

    private

    def spawn
      refill_queue
      @current = Piece.new(@queue.shift, SPAWN_X, SPAWN_Y)
      refill_queue
      @version += 1
      @gravity_counter = 0
      @lock_counter = 0
      @lock_resets = 0
      @over = true unless @board.fits?(@current)
      refresh_grounded
    end

    # Cached after every change of the piece: a frame where nothing moves
    # must not pay for a collision test.
    def refresh_grounded
      @grounded = !@board.fits_at?(@current.kind, @current.x, @current.y + 1, @current.rotation)
    end

    def refill_queue
      @queue.concat(@bag.call(Piece::KINDS)) if @queue.size < 2
    end

    def handle_horizontal(held)
      dir = 0
      dir -= 1 if (held & Pocket::Input::LEFT) != 0
      dir += 1 if (held & Pocket::Input::RIGHT) != 0
      if dir == 0 || dir != @das_dir
        @das_dir = dir
        @das_frames = 0
        try_move(dir, 0) unless dir == 0
        return
      end
      @das_frames += 1
      if @das_frames >= DAS_DELAY && (@das_frames - DAS_DELAY) % DAS_REPEAT == 0
        try_move(dir, 0)
      end
    end

    def try_move(dx, dy)
      return false unless @board.fits_at?(@current.kind, @current.x + dx, @current.y + dy, @current.rotation)
      @current = @current.moved(dx, dy)
      @version += 1
      refresh_grounded
      reset_lock_delay
      true
    end

    def try_rotate(direction)
      rotation = (@current.rotation + direction) % 4
      i = 0
      while i < KICKS.size
        kick = KICKS[i]
        if @board.fits_at?(@current.kind, @current.x + kick[0], @current.y + kick[1], rotation)
          @current = Piece.new(@current.kind, @current.x + kick[0], @current.y + kick[1], rotation)
          @version += 1
          refresh_grounded
          reset_lock_delay
          return true
        end
        i += 1
      end
      false
    end

    def grounded?
      @grounded
    end

    def reset_lock_delay
      return unless @grounded && @lock_resets < LOCK_RESETS
      @lock_counter = 0
      @lock_resets += 1
    end

    def apply_gravity(soft_drop)
      if @grounded
        @lock_counter += 1
        lock if @lock_counter > LOCK_DELAY
        return
      end
      @gravity_counter += 1
      frames = soft_drop ? SOFT_DROP_FRAMES : Game.gravity_frames(@level)
      return if @gravity_counter < frames
      @gravity_counter = 0
      @current = @current.moved(0, 1)
      @version += 1
      @score += 1 if soft_drop
      refresh_grounded
    end

    def hard_drop
      dropped = @board.drop_distance(@current)
      @current = @current.moved(0, dropped) if dropped > 0
      @score += dropped * 2
      lock
    end

    def lock
      @board.place(@current)
      @board_version += 1
      cleared = @board.clear_lines
      @last_cleared = cleared
      if cleared > 0
        @lines += cleared
        @score += LINE_SCORES[cleared] * @level
        @level = Game.level_for(@lines)
      end
      spawn
    end
  end
end
