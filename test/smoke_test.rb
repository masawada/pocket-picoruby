# Checks that the test setup itself works: the wasm build, the node runner
# and the Pocket gem are all reachable from a test.
class SmokeTest < Picotest::Test
  def test_arithmetic
    assert_equal(4, 2 + 2)
  end

  def test_pocket_gem_is_available
    assert_equal(266, Pocket::Display::WIDTH)
    assert_equal(0xf800, Pocket.rgb(255, 0, 0))
  end

  def test_input_state_edges
    state = Pocket::Input::State.new
    state.instance_variable_set(:@previous, 0)
    state.instance_variable_set(:@held, Pocket::Input::A)
    assert(state.pressed?(Pocket::Input::A))
    assert(state.held?(Pocket::Input::A))
    assert_not_equal(true, state.pressed?(Pocket::Input::B))
  end
end
