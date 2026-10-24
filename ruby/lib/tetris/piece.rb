module Tetris
  # A tetromino at a position with a rotation. Cells are listed per rotation
  # as [x, y] offsets inside a 4x4 box (y grows downwards).
  class Piece
    KINDS = %i[I O T S Z J L]

    SHAPES = {
      I: [[[0, 1], [1, 1], [2, 1], [3, 1]],
          [[2, 0], [2, 1], [2, 2], [2, 3]],
          [[0, 2], [1, 2], [2, 2], [3, 2]],
          [[1, 0], [1, 1], [1, 2], [1, 3]]],
      O: [[[1, 0], [2, 0], [1, 1], [2, 1]],
          [[1, 0], [2, 0], [1, 1], [2, 1]],
          [[1, 0], [2, 0], [1, 1], [2, 1]],
          [[1, 0], [2, 0], [1, 1], [2, 1]]],
      T: [[[1, 0], [0, 1], [1, 1], [2, 1]],
          [[1, 0], [1, 1], [2, 1], [1, 2]],
          [[0, 1], [1, 1], [2, 1], [1, 2]],
          [[1, 0], [0, 1], [1, 1], [1, 2]]],
      S: [[[1, 0], [2, 0], [0, 1], [1, 1]],
          [[1, 0], [1, 1], [2, 1], [2, 2]],
          [[1, 1], [2, 1], [0, 2], [1, 2]],
          [[0, 0], [0, 1], [1, 1], [1, 2]]],
      Z: [[[0, 0], [1, 0], [1, 1], [2, 1]],
          [[2, 0], [1, 1], [2, 1], [1, 2]],
          [[0, 1], [1, 1], [1, 2], [2, 2]],
          [[1, 0], [0, 1], [1, 1], [0, 2]]],
      J: [[[0, 0], [0, 1], [1, 1], [2, 1]],
          [[1, 0], [2, 0], [1, 1], [1, 2]],
          [[0, 1], [1, 1], [2, 1], [2, 2]],
          [[1, 0], [1, 1], [0, 2], [1, 2]]],
      L: [[[2, 0], [0, 1], [1, 1], [2, 1]],
          [[1, 0], [1, 1], [1, 2], [2, 2]],
          [[0, 1], [1, 1], [2, 1], [0, 2]],
          [[0, 0], [1, 0], [1, 1], [1, 2]]],
    }

    attr_reader :kind, :x, :y, :rotation

    def initialize(kind, x, y, rotation = 0)
      @kind = kind
      @x = x
      @y = y
      @rotation = rotation % 4
    end

    # Board coordinates of the four cells.
    def cells
      SHAPES[@kind][@rotation].map { |dx, dy| [@x + dx, @y + dy] }
    end

    def rotate(direction)
      @rotation = (@rotation + direction) % 4
      self
    end

    def moved(dx, dy)
      Piece.new(@kind, @x + dx, @y + dy, @rotation)
    end

    def rotated(direction)
      Piece.new(@kind, @x, @y, @rotation + direction)
    end
  end
end
