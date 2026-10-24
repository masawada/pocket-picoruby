class TetrisSequencerTest < Picotest::Test
  def setup
    @played = []
    @seq = Tetris::Sequencer.new([[440, 2], [0, 1], [660, 1]], 3) { |hz, frames| @played << [hz, frames] }
  end

  def test_first_note_fires_on_the_first_frame
    @seq.update
    assert_equal([[440, 6]], @played)
  end

  def test_notes_fire_when_their_time_comes_and_rests_are_silent
    8.times { @seq.update }
    # 440 at frame 0 for 6 frames, rest at frame 6 for 3, 660 at frame 9
    assert_equal([[440, 6]], @played)
    2.times { @seq.update }
    assert_equal([[440, 6], [660, 3]], @played)
  end

  def test_loops_back_to_the_start
    13.times { @seq.update }
    assert_equal([[440, 6], [660, 3], [440, 6]], @played)
    assert_equal(1, @seq.index)
  end

  def test_reset_starts_over
    5.times { @seq.update }
    @seq.reset
    @seq.update
    assert_equal([[440, 6], [440, 6]], @played)
  end

  def test_note_names
    assert_equal(440, Tetris::Sequencer.hz("A4"))
    assert_equal(880, Tetris::Sequencer.hz("A5"))
    assert_equal(659, Tetris::Sequencer.hz("E5"))
    assert_equal(466, Tetris::Sequencer.hz("Bb4"))
    assert_equal(466, Tetris::Sequencer.hz("A#4"))
    assert_equal(82, Tetris::Sequencer.hz("E2"))
    assert_equal(0, Tetris::Sequencer.hz("-"))
  end

  def test_parse
    assert_equal([[659, 4], [494, 2], [0, 2]], Tetris::Sequencer.parse("E5:4 B4:2 -:2"))
  end
end
