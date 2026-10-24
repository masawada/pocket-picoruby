class TetrisBoardTest < Picotest::Test
  def setup
    @board = Tetris::Board.new
  end

  def test_dimensions
    assert_equal(10, Tetris::Board::WIDTH)
    assert_equal(22, Tetris::Board::HEIGHT)
    assert_equal(2, Tetris::Board::HIDDEN_ROWS)
  end

  def test_starts_empty
    assert_equal(nil, @board[0, 0])
    assert_equal(nil, @board[9, 21])
  end

  def test_fits_rejects_out_of_bounds_and_occupied
    assert(@board.fits?(Tetris::Piece.new(:O, 0, 0)))
    assert_equal(false, @board.fits?(Tetris::Piece.new(:O, -2, 0)))
    assert_equal(false, @board.fits?(Tetris::Piece.new(:O, 8, 0)))
    assert_equal(false, @board.fits?(Tetris::Piece.new(:O, 0, 21)))
    @board.place(Tetris::Piece.new(:O, 0, 20))
    assert_equal(false, @board.fits?(Tetris::Piece.new(:O, 0, 20)))
    assert(@board.fits?(Tetris::Piece.new(:O, 2, 20)))
  end

  def test_fits_at_matches_fits
    assert(@board.fits_at?(:T, 3, 0, 0))
    assert_equal(false, @board.fits_at?(:I, 7, 0, 0))   # cells reach x = 10
    assert(@board.fits_at?(:I, 7, 0, 1))                # vertical: x = 9
    assert_equal(false, @board.fits_at?(:I, 0, 19, 1))  # cells reach y = 22
  end

  def test_drop_distance
    assert_equal(20, @board.drop_distance(Tetris::Piece.new(:O, 3, 0)))
    assert_equal(0, @board.drop_distance(Tetris::Piece.new(:O, 3, 20)))
    @board.set(5, 10, :X)
    assert_equal(8, @board.drop_distance(Tetris::Piece.new(:O, 3, 0)))   # cell (5,1) stops at row 9
    assert_equal(20, @board.drop_distance(Tetris::Piece.new(:O, 0, 0)))  # not under the block
  end

  def test_place_records_the_kind
    @board.place(Tetris::Piece.new(:T, 3, 20))
    assert_equal(:T, @board[4, 20])
    assert_equal(:T, @board[3, 21])
    assert_equal(nil, @board[3, 20])
  end

  def test_clear_lines_removes_full_rows_and_drops_the_rest
    fill_row(21, except: nil)
    fill_row(20, except: 0)
    @board.set(5, 19, :I)
    assert_equal(1, @board.clear_lines)
    assert_equal(nil, @board[0, 21])  # the row with the gap moved down
    assert_equal(:X, @board[1, 21])
    assert_equal(:X, @board[9, 21])
    assert_equal(:I, @board[5, 20])
    assert_equal(nil, @board[5, 19])
  end

  def test_clear_lines_counts_multiple_rows
    fill_row(21)
    fill_row(20)
    fill_row(19)
    fill_row(18)
    assert_equal(4, @board.clear_lines)
    assert_equal(nil, @board[0, 21])
  end

  def test_clear_lines_returns_zero_when_nothing_is_full
    fill_row(21, except: 3)
    assert_equal(0, @board.clear_lines)
    assert_equal(:X, @board[0, 21])
  end

  private

  def fill_row(y, except: nil)
    Tetris::Board::WIDTH.times do |x|
      @board.set(x, y, :X) unless x == except
    end
  end
end
