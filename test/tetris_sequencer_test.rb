class TetrisSequencerTest < Picotest::Test
  def setup
    @played = []
    @seq = Tetris::Sequencer.new([[440, 2], [0, 1], [660, 1]], 3) { |hz, frames| @played << [hz, frames] }
  end

  def test_first_note_fires_on_frame_zero
    @seq.update(0)
    assert_equal([[440, 6]], @played)
  end

  def test_notes_fire_when_their_time_comes_and_rests_are_silent
    # 440 at frame 0 for 6 frames, rest at frame 6 for 3, 660 at frame 9
    (0..8).each { |f| @seq.update(f) }
    assert_equal([[440, 6]], @played)
    @seq.update(9)
    assert_equal([[440, 6], [660, 3]], @played)
  end

  def test_loops_back_to_the_start
    (0..12).each { |f| @seq.update(f) }
    assert_equal([[440, 6], [660, 3], [440, 6]], @played)
    assert_equal(1, @seq.index)
  end

  def test_dropped_frames_do_not_stretch_the_track
    @seq.update(0)
    # Frames 1..10 were never seen: the 660 due at frame 9 fires now for the
    # one frame it has left, and the 440 due at frame 12 still comes at 12.
    @seq.update(11)
    assert_equal([[440, 6], [660, 1]], @played)
    @seq.update(12)
    assert_equal([[440, 6], [660, 1], [440, 6]], @played)
  end

  def test_catching_up_plays_only_what_still_sounds
    # Nothing was seen until frame 13: the 440 of frames 0..5 and the 660 of
    # frames 9..11 are over, the 440 that began at 12 has 5 frames left.
    @seq.update(13)
    assert_equal([[440, 5]], @played)
    assert_equal(1, @seq.index)
  end

  def test_reset_starts_over
    (0..4).each { |f| @seq.update(f) }
    @seq.reset
    @seq.update(0)
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
