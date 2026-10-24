module Tetris
  # The well: WIDTH x HEIGHT cells, the top HIDDEN_ROWS not shown. A cell holds
  # the kind of the piece that locked there, or nil.
  #
  # The hot paths use while loops and index the shape table directly instead
  # of allocating cell arrays: on the Pocket a Ruby op costs ~5 us, so a frame
  # affords only a few thousand of them.
  class Board
    WIDTH = 10
    HEIGHT = 22
    HIDDEN_ROWS = 2

    def initialize
      clear
    end

    def clear
      @rows = Array.new(HEIGHT) { Array.new(WIDTH, nil) }
    end

    def [](x, y)
      @rows[y][x]
    end

    def set(x, y, kind)
      @rows[y][x] = kind
    end

    def row(y)
      @rows[y]
    end

    # True when every cell of the piece is inside the well and empty.
    def fits?(piece)
      fits_at?(piece.kind, piece.x, piece.y, piece.rotation)
    end

    def fits_at?(kind, px, py, rotation)
      shape = Piece::SHAPES[kind][rotation]
      i = 0
      while i < 4
        d = shape[i]
        x = px + d[0]
        y = py + d[1]
        return false if x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT
        return false if @rows[y][x]
        i += 1
      end
      true
    end

    # How many rows the piece can fall before it rests on something.
    def drop_distance(piece)
      shape = Piece::SHAPES[piece.kind][piece.rotation]
      best = HEIGHT
      i = 0
      while i < 4
        d = shape[i]
        x = piece.x + d[0]
        y = piece.y + d[1] + 1
        n = 0
        while y < HEIGHT && @rows[y][x].nil?
          y += 1
          n += 1
        end
        best = n if n < best
        i += 1
      end
      best
    end

    def place(piece)
      piece.cells.each { |x, y| @rows[y][x] = piece.kind }
    end

    # Removes full rows, shifts everything above them down, returns the count.
    def clear_lines
      kept = @rows.reject { |row| row.all? { |cell| cell } }
      cleared = HEIGHT - kept.size
      cleared.times { kept.unshift(Array.new(WIDTH, nil)) }
      @rows = kept
      cleared
    end
  end
end
