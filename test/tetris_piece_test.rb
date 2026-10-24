class TetrisPieceTest < Picotest::Test
  def test_every_shape_has_four_rotations_of_four_cells
    Tetris::Piece::SHAPES.each do |kind, rotations|
      assert_equal(4, rotations.size)
      rotations.each do |cells|
        assert_equal(4, cells.size)
        assert_equal(4, cells.uniq.size)
      end
    end
  end

  def test_seven_kinds
    assert_equal(%i[I O T S Z J L], Tetris::Piece::KINDS)
  end

  def test_cells_are_offset_by_position
    piece = Tetris::Piece.new(:O, 3, 0)
    assert_equal([[4, 0], [5, 0], [4, 1], [5, 1]], piece.cells)
  end

  def test_rotation_wraps
    piece = Tetris::Piece.new(:T, 0, 0)
    assert_equal(0, piece.rotation)
    piece.rotate(1)
    assert_equal(1, piece.rotation)
    piece.rotate(-2)
    assert_equal(3, piece.rotation)
    piece.rotate(1)
    assert_equal(0, piece.rotation)
  end

  def test_moved_returns_a_copy
    piece = Tetris::Piece.new(:I, 3, 0)
    moved = piece.moved(1, 2)
    assert_equal(3, piece.x)
    assert_equal(4, moved.x)
    assert_equal(2, moved.y)
    assert_equal(:I, moved.kind)
  end
end
