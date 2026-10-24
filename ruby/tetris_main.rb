# Tetris for the Pocket: rendering and the main loop. The rules live in
# ruby/lib/tetris/; scripts/bundle-rb.rb joins them with this file into one
# script (build/tetris.rb) because the device loads a single .rb.
#
# Controls: d-pad left/right move, down soft drop, up hard drop, A/B rotate,
#           Start pauses (up/down pick Resume or Restart, A or Start confirms)
#           and restarts after game over.
#
# Drawing is budgeted for the Pocket, where a Ruby op costs ~5 us: a frame
# where nothing moved draws nothing, a move erases and draws 16 cells at most,
# and only a lock that cleared lines repaints the whole well.

module Tetris
  class Renderer
    D = Pocket::Display
    CELL = 10
    BOARD_X = 28
    BOARD_Y = 20
    VISIBLE_ROWS = Board::HEIGHT - Board::HIDDEN_ROWS
    PANEL_X = 150
    NEXT_Y = 36

    BG = Pocket.rgb(12, 12, 24)
    WELL = Pocket.rgb(0, 0, 0)
    FRAME = Pocket.rgb(90, 90, 120)
    TEXT = Pocket.rgb(230, 230, 230)
    LABEL = Pocket.rgb(140, 140, 170)
    GHOST = Pocket.rgb(50, 50, 70)
    COLOURS = {
      I: Pocket.rgb(0, 220, 220),
      O: Pocket.rgb(240, 220, 0),
      T: Pocket.rgb(180, 0, 220),
      S: Pocket.rgb(0, 210, 60),
      Z: Pocket.rgb(230, 40, 40),
      J: Pocket.rgb(40, 80, 240),
      L: Pocket.rgb(240, 140, 0),
      X: Pocket.rgb(128, 128, 128),
    }

    def initialize
      @last_cells = Array.new(Board::WIDTH * VISIBLE_ROWS, nil)
      @last_next = nil
      @last_score = nil
      @last_lines = nil
      @last_level = nil
      @last_over = nil
      @last_version = nil
      @last_board_version = nil
      @piece_cells = []  # well indices currently showing the falling piece
      @ghost_cells = []  # well indices currently showing the ghost
      draw_static
    end

    def draw_static
      D.clear(BG)
      D.fill_rect(BOARD_X - 2, BOARD_Y - 2, Board::WIDTH * CELL + 4, VISIBLE_ROWS * CELL + 4, FRAME)
      D.fill_rect(BOARD_X, BOARD_Y, Board::WIDTH * CELL, VISIBLE_ROWS * CELL, WELL)
      D.draw_text(PANEL_X, NEXT_Y - 18, "NEXT", LABEL)
      D.draw_text(PANEL_X, 100, "SCORE", LABEL)
      D.draw_text(PANEL_X, 140, "LINES", LABEL)
      D.draw_text(PANEL_X, 180, "LEVEL", LABEL)
      D.flush
    end

    def draw(game)
      if game.version != @last_version
        @last_version = game.version
        if game.board_version == @last_board_version
          draw_piece_move(game)
        elsif game.last_cleared == 0 && @last_board_version
          @last_board_version = game.board_version
          draw_lock(game)
        else
          @last_board_version = game.board_version
          draw_well(game)
        end
      end
      draw_next(game.next_kind)
      draw_number(116, game.score, @last_score); @last_score = game.score
      draw_number(156, game.lines, @last_lines); @last_lines = game.lines
      draw_number(196, game.level, @last_level); @last_level = game.level
      draw_over(game.over?)
      draw_pause(game)
    end

    private

    # The well did not change: erase where the piece and its ghost were and
    # draw them where they are now.
    def draw_piece_move(game)
      erase_cells(@ghost_cells)
      erase_cells(@piece_cells)
      @ghost_cells = game.over? ? [] : cell_indices(game.ghost)
      @piece_cells = cell_indices(game.current)
      paint_cells(@ghost_cells, GHOST)
      paint_cells(@piece_cells, COLOURS[game.current.kind])
    end

    # A piece locked without clearing lines. Every cell that showed the piece
    # or its ghost is repainted from the well: the ghost usually sat exactly
    # where the piece came to rest, and after a hard drop the piece was last
    # drawn well above it. A cell the well now owns gets its colour, an empty
    # one is erased.
    def draw_lock(game)
      settle_cells(game.board, @ghost_cells)
      settle_cells(game.board, @piece_cells)
      @ghost_cells = []
      @piece_cells = []
      draw_piece_move(game)
    end

    def settle_cells(board, indices)
      i = 0
      while i < indices.size
        idx = indices[i]
        kind = board.row(idx / Board::WIDTH + Board::HIDDEN_ROWS)[idx % Board::WIDTH]
        if kind
          paint_cells([idx], COLOURS[kind])
        else
          erase_cells([idx])
        end
        i += 1
      end
    end

    def cell_indices(piece)
      out = []
      cells = piece.cells
      i = 0
      while i < 4
        c = cells[i]
        out << (c[1] - Board::HIDDEN_ROWS) * Board::WIDTH + c[0] if c[1] >= Board::HIDDEN_ROWS
        i += 1
      end
      out
    end

    def erase_cells(indices)
      i = 0
      while i < indices.size
        idx = indices[i]
        @last_cells[idx] = WELL
        D.fill_rect(BOARD_X + (idx % Board::WIDTH) * CELL, BOARD_Y + (idx / Board::WIDTH) * CELL, CELL, CELL, WELL)
        i += 1
      end
    end

    def paint_cells(indices, colour)
      i = 0
      while i < indices.size
        idx = indices[i]
        @last_cells[idx] = colour
        D.fill_rect(BOARD_X + (idx % Board::WIDTH) * CELL, BOARD_Y + (idx / Board::WIDTH) * CELL, CELL - 1, CELL - 1, colour)
        i += 1
      end
    end

    # Full repaint of cells whose colour changed (after line clears, restart).
    def draw_well(game)
      board = game.board
      cells = Array.new(Board::WIDTH * VISIBLE_ROWS, WELL)
      y = Board::HIDDEN_ROWS
      i = 0
      while y < Board::HEIGHT
        row = board.row(y)
        x = 0
        while x < Board::WIDTH
          kind = row[x]
          cells[i] = COLOURS[kind] if kind
          x += 1
          i += 1
        end
        y += 1
      end
      @ghost_cells = game.over? ? [] : cell_indices(game.ghost)
      @piece_cells = cell_indices(game.current)
      @ghost_cells.each { |idx| cells[idx] = GHOST }
      colour = COLOURS[game.current.kind]
      @piece_cells.each { |idx| cells[idx] = colour }

      i = 0
      while i < cells.size
        c = cells[i]
        if c != @last_cells[i]
          @last_cells[i] = c
          px = BOARD_X + (i % Board::WIDTH) * CELL
          py = BOARD_Y + (i / Board::WIDTH) * CELL
          if c == WELL
            D.fill_rect(px, py, CELL, CELL, WELL)
          else
            D.fill_rect(px, py, CELL - 1, CELL - 1, c)
          end
        end
        i += 1
      end
    end

    def draw_next(kind)
      return if kind == @last_next
      @last_next = kind
      D.fill_rect(PANEL_X, NEXT_Y, 4 * CELL, 4 * CELL, BG)
      Piece.new(kind, 0, 0).cells.each do |cx, cy|
        D.fill_rect(PANEL_X + cx * CELL, NEXT_Y + cy * CELL, CELL - 1, CELL - 1, COLOURS[kind])
      end
    end

    def draw_number(y, value, last)
      return if value == last
      D.draw_text(PANEL_X, y, value.to_s.rjust(8), TEXT, BG)
    end

    def draw_pause(game)
      paused = game.paused?
      if paused != @last_paused
        @last_paused = paused
        if paused
          D.fill_rect(BOARD_X, BOARD_Y + 70, Board::WIDTH * CELL, 64, WELL)
          D.draw_text(BOARD_X + 26, BOARD_Y + 76, "PAUSED", TEXT)
          @last_selection = nil
        else
          # Repaint the well under the menu.
          @last_cells = Array.new(@last_cells.size, nil)
          @last_version = nil
          @last_board_version = nil
          return
        end
      end
      return unless paused
      selection = game.pause_selection
      return if selection == @last_selection
      @last_selection = selection
      D.draw_text(BOARD_X + 10, BOARD_Y + 96, (selection == :resume ? "> " : "  ") + "RESUME", TEXT, WELL)
      D.draw_text(BOARD_X + 10, BOARD_Y + 112, (selection == :restart ? "> " : "  ") + "RESTART", TEXT, WELL)
    end

    def draw_over(over)
      return if over == @last_over
      @last_over = over
      if over
        D.fill_rect(BOARD_X, BOARD_Y + 80, Board::WIDTH * CELL, 44, WELL)
        D.draw_text(BOARD_X + 14, BOARD_Y + 86, "GAME OVER", TEXT)
        D.draw_text(BOARD_X + 10, BOARD_Y + 104, "START: new", LABEL)
      else
        # Force every cell to be redrawn over the banner.
        @last_cells = Array.new(@last_cells.size, nil)
        @last_version = nil
        @last_board_version = nil
      end
    end
  end
end

module Tetris
  # Background music: Korobeiniki (traditional) on two voices, one frame at a
  # time through Sequencer. Units are sixteenth notes; 4 frames each is about
  # 112 bpm. Stops on game over, restarts with the game.
  class Music
    A = Pocket::Audio
    UNIT_FRAMES = 4
    MELODY_VOICE = 2
    BASS_VOICE = 3

    MELODY = Sequencer.parse(<<~SCORE)
      E5:4 B4:2 C5:2 D5:4 C5:2 B4:2
      A4:4 A4:2 C5:2 E5:4 D5:2 C5:2
      B4:6 C5:2 D5:4 E5:4
      C5:4 A4:4 A4:4 -:4
      -:2 D5:4 F5:2 A5:4 G5:2 F5:2
      E5:6 C5:2 E5:4 D5:2 C5:2
      B4:4 B4:2 C5:2 D5:4 E5:4
      C5:4 A4:4 A4:4 -:4
    SCORE

    BASS = Sequencer.parse(<<~SCORE)
      E2:2 E3:2 E2:2 E3:2 E2:2 E3:2 E2:2 E3:2
      A2:2 A3:2 A2:2 A3:2 A2:2 A3:2 A2:2 A3:2
      G#2:2 G#3:2 G#2:2 G#3:2 E2:2 E3:2 E2:2 E3:2
      A2:2 A3:2 A2:2 A3:2 A2:2 A3:2 B2:2 C3:2
      D2:2 D3:2 D2:2 D3:2 D2:2 D3:2 D2:2 D3:2
      C2:2 C3:2 C2:2 C3:2 C2:2 C3:2 C2:2 C3:2
      G#2:2 G#3:2 G#2:2 G#3:2 E2:2 E3:2 E2:2 E3:2
      A2:2 A3:2 A2:2 A3:2 A2:2 A3:2 A2:2 A3:2
    SCORE

    def initialize
      @melody = Sequencer.new(MELODY, UNIT_FRAMES) do |hz, frames|
        A.play(MELODY_VOICE, hz, frames * 1000 / 60 - 25, wave: :square, volume: 55)
      end
      @bass = Sequencer.new(BASS, UNIT_FRAMES) do |hz, frames|
        A.play(BASS_VOICE, hz, frames * 1000 / 60 - 15, wave: :triangle, volume: 90)
      end
      @playing = true
    end

    def update(game)
      if game.over? || game.paused?
        return unless @playing
        @playing = false
        @board_version_at_stop = game.board_version
        A.stop(MELODY_VOICE)
        A.stop(BASS_VOICE)
        return
      end
      unless @playing
        @playing = true
        # A new game (restart bumps board_version) starts the song over; a
        # resumed one carries on where it stopped.
        if game.board_version != @board_version_at_stop
          @melody.reset
          @bass.reset
        end
      end
      @melody.update
      @bass.update
    end
  end

  # Sound effects, derived from what changed in the game since the last frame
  # (the same version counters the renderer uses), so the rules stay silent
  # about sound. Voice 0: moves and rotations, 1: locks, clears and game over;
  # voices 2 and 3 belong to Music.
  class Sfx
    A = Pocket::Audio

    def initialize(game)
      remember(game)
      @over = game.over?
      @paused = game.paused?
      @selection = game.pause_selection
    end

    def update(game)
      over = game.over?
      if over != @over
        @over = over
        A.play(1, 500, 700, wave: :saw, slide_to: 60, volume: 150, decay: true) if over
        remember(game)
        return
      end
      paused = game.paused?
      if paused != @paused
        @paused = paused
        @selection = game.pause_selection
        A.play(0, 660, 50, wave: :triangle, volume: 80)
        remember(game)
        return
      end
      if paused
        if game.pause_selection != @selection
          @selection = game.pause_selection
          A.play(0, 990, 25, volume: 70)
        end
        return
      end
      if game.board_version != @board_version
        case game.last_cleared
        when 0 then A.play(1, 140, 50, wave: :square, volume: 110)
        when 4
          A.play(0, 523, 90, wave: :triangle, volume: 160)
          A.play(1, 784, 180, wave: :triangle, volume: 160, decay: true)
        else A.play(1, 400, 140, wave: :square, slide_to: 1400, volume: 120, decay: true)
        end
      elsif game.version != @version
        piece = game.current
        if piece.rotation != @rotation
          A.play(0, 1300, 35, wave: :triangle, volume: 90)
        elsif piece.x != @x
          A.play(0, 900, 18, wave: :square, volume: 60)
        end
      end
      remember(game)
    end

    private

    def remember(game)
      @version = game.version
      @board_version = game.board_version
      @x = game.current.x
      @rotation = game.current.rotation
    end
  end
end

game = Tetris::Game.new
renderer = Tetris::Renderer.new
sfx = Tetris::Sfx.new(game)
music = Tetris::Music.new
input = Pocket::Input::State.new

loop do
  input.update
  game.update(input)
  sfx.update(game)
  music.update(game)
  renderer.draw(game)
  Pocket.wait_vsync
  Pocket::Display.flush
end
