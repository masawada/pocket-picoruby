class PocketDisplayTest < Picotest::Test
  def test_dimensions
    assert_equal(266, Pocket::Display::WIDTH)
    assert_equal(240, Pocket::Display::HEIGHT)
    assert_equal(8, Pocket::Display::FONT_WIDTH)
    assert_equal(16, Pocket::Display::FONT_HEIGHT)
  end

  def test_draw_text_accepts_utf8
    assert_nil(Pocket::Display.draw_text(0, 0, "ASCII", 0xffff))
    assert_nil(Pocket::Display.draw_text(0, 16, "日本語とカナ、ＡＢＣ", 0xffff, 0))
    assert_nil(Pocket::Display.draw_text(0, 32, "mixed 混在 text", 0xffff))
    assert_nil(Pocket::Display.draw_text(0, 48, "unmapped \u{1F3AE} emoji", 0xffff))
  end

  def test_draw_text_clips_off_screen
    assert_nil(Pocket::Display.draw_text(-10, -10, "clipped 端", 0xffff))
    assert_nil(Pocket::Display.draw_text(260, 236, "clipped 端", 0xffff))
  end

  def test_colour_range
    assert_raise(ArgumentError) { Pocket::Display.fill_rect(0, 0, 1, 1, 0x10000) }
    assert_raise(ArgumentError) { Pocket::Display.fill_rect(0, 0, 1, 1, -1) }
  end
end
