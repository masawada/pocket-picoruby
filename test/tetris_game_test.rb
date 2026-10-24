# Drives Tetris::Game frame by frame with a scripted input, no screen involved.
# Exposes the same held/previous bitmaps as Pocket::Input::State.
class FakeInput
  attr_reader :held, :previous

  def initialize
    @held = 0
    @previous = 0
  end

  def press(mask)
    @previous = @held
    @held |= mask
  end

  def release(mask)
    @previous = @held
    @held &= ~mask
  end

  # Settle edges: the next frame sees the keys as merely held.
  def next_frame
    @previous = @held
  end

  def held?(mask)
    (@held & mask) != 0
  end

  def pressed?(mask)
    (@held & ~@previous & mask) != 0
  end
end

class TetrisGameTest < Picotest::Test

  def setup
    @input = FakeInput.new
    # A fixed bag order makes spawns predictable: O first, then I.
    @game = Tetris::Game.new(bag: ->(kinds) { [:O, :I, :T, :S, :Z, :J, :L] })
  end

  def step(frames = 1)
    frames.times do
      @game.update(@input)
      @input.next_frame
    end
  end

  def test_initial_state
    assert_equal(:O, @game.current.kind)
    assert_equal(:I, @game.next_kind)
    assert_equal(0, @game.score)
    assert_equal(0, @game.lines)
    assert_equal(1, @game.level)
    assert_equal(false, @game.over?)
  end

  def test_spawns_centred_on_the_hidden_rows
    assert_equal(3, @game.current.x)
    assert_equal(0, @game.current.y)
  end

  def test_left_and_right_move_once_per_press
    x = @game.current.x
    @input.press(Pocket::Input::LEFT)
    step
    assert_equal(x - 1, @game.current.x)
    step(3)
    assert_equal(x - 1, @game.current.x) # held but before auto-repeat kicks in
    @input.release(Pocket::Input::LEFT)
    @input.press(Pocket::Input::RIGHT)
    step
    assert_equal(x, @game.current.x)
  end

  def test_holding_a_direction_auto_repeats
    x = @game.current.x
    @input.press(Pocket::Input::LEFT)
    # One move on the press, the first repeat once DAS_DELAY frames have been
    # held, then one every DAS_REPEAT frames.
    step(1 + Tetris::Game::DAS_DELAY)
    assert_equal(x - 2, @game.current.x)
    step(Tetris::Game::DAS_REPEAT)
    assert_equal(x - 3, @game.current.x)
  end

  def test_cannot_move_through_the_wall
    @input.press(Pocket::Input::LEFT)
    step(60)
    # The O's cells sit at offsets 1..2, so its x is -1 against the wall.
    assert_equal(0, @game.current.cells.map { |x, _y| x }.min)
  end

  def test_version_changes_only_when_something_moves
    v = @game.version
    step
    assert_equal(v, @game.version)
    @input.press(Pocket::Input::LEFT)
    step
    assert_equal(v + 1, @game.version)
    @input.release(Pocket::Input::LEFT)
    step(Tetris::Game.gravity_frames(1))
    assert_equal(v + 2, @game.version)
  end

  def test_last_cleared_reports_the_lines_of_the_latest_lock
    assert_equal(0, @game.last_cleared)
    [0, 1, 2, 3, 6, 7, 8, 9].each { |x| @game.board.set(x, 21, :X) }
    @input.press(Pocket::Input::UP)
    step
    assert_equal(1, @game.last_cleared)
    @input.release(Pocket::Input::UP)
    @input.press(Pocket::Input::UP)
    step
    assert_equal(0, @game.last_cleared)
  end

  def test_ghost_rests_on_the_stack
    @game.board.set(4, 15, :X)
    ghost = @game.ghost
    assert_equal(:O, ghost.kind)
    assert_equal(13, ghost.y)   # O occupies rows y+0..y+1, stopping above row 15
    assert_equal(@game.current.x, ghost.x)
  end

  def test_board_version_changes_only_when_the_well_changes
    v = @game.board_version
    @input.press(Pocket::Input::LEFT)
    step
    assert_equal(v, @game.board_version)
    @input.release(Pocket::Input::LEFT)
    @input.press(Pocket::Input::UP)
    step
    assert_equal(v + 1, @game.board_version)
  end

  def test_gravity_moves_the_piece_down
    step(Tetris::Game.gravity_frames(1))
    assert_equal(1, @game.current.y)
  end

  def test_hard_drop_locks_and_spawns_next
    @input.press(Pocket::Input::UP)
    step
    assert_equal(:I, @game.current.kind)
    assert_equal(:O, @game.board[4, 21])
    assert_equal(:O, @game.board[5, 20])
    assert_equal(:T, @game.next_kind)
  end

  def test_rotate_changes_rotation_and_kicks_off_the_wall
    @input.press(Pocket::Input::LEFT)
    step(60)
    @input.release(Pocket::Input::LEFT)
    @input.press(Pocket::Input::UP)
    step
    # Now the I piece is current; push it to the left wall and rotate.
    @input.release(Pocket::Input::UP)
    @input.press(Pocket::Input::LEFT)
    step(60)
    @input.release(Pocket::Input::LEFT)
    @input.press(Pocket::Input::A)
    step
    assert_equal(1, @game.current.rotation)
    assert(@game.board.fits?(@game.current))
  end

  def test_lock_delay_lets_the_piece_slide_before_locking
    # Soft-drop the O to the floor (20 rows, SOFT_DROP_FRAMES each), then it
    # should stay movable for LOCK_DELAY frames and lock afterwards.
    @input.press(Pocket::Input::DOWN)
    step(20 * Tetris::Game::SOFT_DROP_FRAMES)
    @input.release(Pocket::Input::DOWN)
    assert_equal(:O, @game.current.kind)
    assert_equal(20, @game.current.y)
    @input.press(Pocket::Input::LEFT)
    step
    assert_equal(2, @game.current.x)
    @input.release(Pocket::Input::LEFT)
    step(Tetris::Game::LOCK_DELAY + 1)
    assert_equal(:I, @game.current.kind)
    assert_equal(:O, @game.board[3, 21]) # O cells sit at x + 1 and x + 2
  end

  def test_clearing_lines_scores_and_counts
    # Fill the bottom row except where the O will land (x 4..5), then drop it.
    board = @game.board
    [0, 1, 2, 3, 6, 7, 8, 9].each do |x|
      board.set(x, 20, :X)
      board.set(x, 21, :X)
    end
    @input.press(Pocket::Input::UP)
    step
    assert_equal(2, @game.lines)
    # 300 for a double at level 1, plus 2 points per row of the hard drop (20 rows).
    assert_equal(340, @game.score)
    assert_equal(nil, board[0, 21])
  end

  def test_level_rises_every_ten_lines
    assert_equal(1, Tetris::Game.level_for(0))
    assert_equal(1, Tetris::Game.level_for(9))
    assert_equal(2, Tetris::Game.level_for(10))
    assert_equal(4, Tetris::Game.level_for(35))
    assert(Tetris::Game.gravity_frames(1) > Tetris::Game.gravity_frames(5))
  end

  def test_game_over_when_the_spawn_is_blocked
    board = @game.board
    (0...Tetris::Board::HEIGHT).each do |y|
      board.set(4, y, :X)
    end
    @input.press(Pocket::Input::UP)
    step
    assert(@game.over?)
    frozen = @game.current.y
    step(10)
    assert_equal(frozen, @game.current.y)
  end

  def test_start_pauses_and_freezes_the_game
    assert_equal(false, @game.paused?)
    @input.press(Pocket::Input::START)
    step
    assert(@game.paused?)
    assert_equal(:resume, @game.pause_selection)
    @input.release(Pocket::Input::START)
    y = @game.current.y
    step(Tetris::Game.gravity_frames(1) * 2)
    assert_equal(y, @game.current.y)
    @input.press(Pocket::Input::LEFT)
    step
    assert_equal(3, @game.current.x)
    @input.release(Pocket::Input::LEFT)
  end

  def test_pause_menu_resume
    @input.press(Pocket::Input::START)
    step
    @input.release(Pocket::Input::START)
    @input.press(Pocket::Input::DOWN)
    step
    assert_equal(:restart, @game.pause_selection)
    @input.release(Pocket::Input::DOWN)
    @input.press(Pocket::Input::UP)
    step
    assert_equal(:resume, @game.pause_selection)
    @input.release(Pocket::Input::UP)
    @input.press(Pocket::Input::A)
    step
    assert_equal(false, @game.paused?)
    assert_equal(:O, @game.current.kind)
  end

  def test_pause_menu_restart
    @input.press(Pocket::Input::UP)
    step
    assert_equal(:O, @game.board[4, 21])
    @input.release(Pocket::Input::UP)
    @input.press(Pocket::Input::START)
    step
    @input.release(Pocket::Input::START)
    @input.press(Pocket::Input::DOWN)
    step
    @input.release(Pocket::Input::DOWN)
    @input.press(Pocket::Input::START)
    step
    assert_equal(false, @game.paused?)
    assert_equal(nil, @game.board[4, 21])
    assert_equal(0, @game.score)
  end

  def test_restart_after_game_over
    (0...Tetris::Board::HEIGHT).each { |y| @game.board.set(4, y, :X) }
    @input.press(Pocket::Input::UP)
    step
    assert(@game.over?)
    @input.release(Pocket::Input::UP)
    @input.press(Pocket::Input::START)
    step
    assert_equal(false, @game.over?)
    assert_equal(0, @game.score)
    assert_equal(nil, @game.board[4, 21])
  end
end
