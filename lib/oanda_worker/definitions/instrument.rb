module Definitions
  module Instrument
    CANDLESTICK_GRANULARITY = {
      5         => 'S5',
      10        => 'S10',
      15        => 'S15',
      30        => 'S30',
      60        => 'M1',
      120       => 'M2',
      180       => 'M3',
      240       => 'M4',
      300       => 'M5',
      600       => 'M10',
      900       => 'M15',
      1_800     => 'M30',
      3_600     => 'H1',
      7_200     => 'H2',
      10_800    => 'H3',
      14_400    => 'H4',
      21_600    => 'H6',
      28_800    => 'H8',
      43_200    => 'H12',
      86_400    => 'D',
      604_800   => 'W',
      2_678_400 => 'M'
    }

    class << self
      # Rounds down to closest value.
      # TODO: Maybe throw an exception.
      def candlestick_granularity(seconds)
        return CANDLESTICK_GRANULARITY[seconds] if CANDLESTICK_GRANULARITY[seconds]

        return CANDLESTICK_GRANULARITY.values[0] if seconds < CANDLESTICK_GRANULARITY.keys[0]

        CANDLESTICK_GRANULARITY.keys.each_with_index do |key, i|
          return CANDLESTICK_GRANULARITY.values[i - 1] if seconds < key
        end

        return CANDLESTICK_GRANULARITY.values[-1]
      end

      def granularity_seconds(granularity)
        CANDLESTICK_GRANULARITY.select{ |key, value| value == granularity }.keys.last
      end
    end
  end
end
