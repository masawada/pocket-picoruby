class PocketAudioTest < Picotest::Test
  def teardown
    Pocket::Audio.stop
  end

  def test_four_voices
    assert_equal(4, Pocket::Audio::VOICES)
  end

  def test_play_marks_the_voice_active_until_stopped
    Pocket::Audio.play(0, 440, 1000)
    assert(Pocket::Audio.active?(0))
    assert_equal(false, Pocket::Audio.active?(1))
    Pocket::Audio.stop(0)
    assert_equal(false, Pocket::Audio.active?(0))
  end

  def test_stop_without_a_voice_silences_everything
    Pocket::Audio.play(1, 440, 1000, wave: :triangle)
    Pocket::Audio.play(2, 440, 1000, wave: :saw, slide_to: 880, decay: true)
    Pocket::Audio.play(3, 440, 1000, wave: :noise)
    Pocket::Audio.stop
    assert_equal(false, Pocket::Audio.active?(1))
    assert_equal(false, Pocket::Audio.active?(2))
    assert_equal(false, Pocket::Audio.active?(3))
  end

  def test_rejects_bad_arguments
    assert_raise(ArgumentError) { Pocket::Audio.play(4, 440, 100) }
    assert_raise(ArgumentError) { Pocket::Audio.play(0, 440, 100, wave: :sine) }
  end

  def test_zero_length_or_silent_notes_do_not_play
    Pocket::Audio.play(0, 440, 0)
    assert_equal(false, Pocket::Audio.active?(0))
    Pocket::Audio.play(0, 440, 100, volume: 0)
    assert_equal(false, Pocket::Audio.active?(0))
  end
end
