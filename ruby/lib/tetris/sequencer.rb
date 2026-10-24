module Tetris
  # Steps through a track one frame at a time and fires notes on schedule.
  # A track is an array of [hz, units]; hz 0 is a rest; a unit lasts
  # unit_frames frames. The block receives (hz, frames) for every note and
  # is what actually makes sound, so the timing can be tested without audio.
  class Sequencer
    attr_reader :index

    def initialize(track, unit_frames, &player)
      @track = track
      @unit_frames = unit_frames
      @player = player
      reset
    end

    def reset
      @index = 0
      @frame = 0
      @next_at = 0
    end

    # Call once per frame. Cheap when no note is due (two comparisons).
    def update
      if @frame >= @next_at
        note = @track[@index]
        frames = note[1] * @unit_frames
        @player.call(note[0], frames) if note[0] > 0
        @next_at += frames
        @index += 1
        @index = 0 if @index >= @track.size
      end
      @frame += 1
    end

    # Hz of a note name such as "E5" or "Bb3", equal temperament, A4 = 440.
    SEMITONES = { "C" => -9, "D" => -7, "E" => -5, "F" => -4, "G" => -2, "A" => 0, "B" => 2 }

    def self.hz(name)
      return 0 if name == "-"
      letter = name[0]
      rest = name[1..-1]
      semitone = SEMITONES[letter]
      if rest[0] == "#"
        semitone += 1
        rest = rest[1..-1]
      elsif rest[0] == "b"
        semitone -= 1
        rest = rest[1..-1]
      end
      octave = rest.to_i
      (440.0 * (2.0 ** ((semitone + (octave - 4) * 12) / 12.0))).round
    end

    # "E5:4 B4:2 -:2" -> [[659, 4], [494, 2], [0, 2]]
    def self.parse(score)
      score.split.map do |token|
        name, units = token.split(":")
        [hz(name), units.to_i]
      end
    end
  end
end
