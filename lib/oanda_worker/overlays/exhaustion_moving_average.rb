# Author: Francois Joubert.
module Overlays
  class ExhaustionMovingAverage < Overlay
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead
    attr_reader   :highest_highs, :lowest_lows, :top_simple_moving_averages, :bottom_simple_moving_averages,
                  :average_body_sizes, :top_shadow_sizes, :bottom_shadow_sizes

    def initialize(options = {})
      super
      @count         ||= 6
      @plotted_ahead ||= 0 # NOTE: Only works for the singular points average_body_size, top_shadow_size and bottom_shadow_size.
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{(count * 2 - 1) + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < (count * 2 - 1) + plotted_ahead
      @candles                       = candles.dup
      @highest_highs                 = []
      @lowest_lows                   = []
      @top_simple_moving_averages    = []
      @bottom_simple_moving_averages = []
      @average_body_sizes            = []
      @top_shadow_sizes              = []
      @bottom_shadow_sizes           = []

      (candles['candles'].count - (count * 2 - 2)).times do |i|
        # With a count setting of 3, we need 5 candles to calculate the average highest tops & bottoms.
        # Loop over the first 3 candles to determine the highest top & highest bottom for use in calulating the initial average top & bottom.
        # When on the 3rd candle, we now have the highest top & bottom for calculating the initial average top & bottom.
        # From the 3rd candle and onwards, we can now calculate the average tops & bottoms.
        highest_tops_sum   = 0
        lowest_bottoms_sum = 0
        highest_high       = candles['candles'][i + count - 1]['mid']['h'].to_f
        lowest_low         = candles['candles'][i + count - 1]['mid']['l'].to_f

        count.times do |j|
          candle_top    = nil
          candle_bottom = nil
          highest_top   = nil
          lowest_bottom = nil

          # Highest tops and bottoms. # [0..2]
          count.times do |k|
            candle       = candles['candles'][i + j + k]
            candle_open  = candle['mid']['o'].to_f
            candle_close = candle['mid']['c'].to_f

            if candle_open > candle_close
              candle_top    = candle_open
              candle_bottom = candle_close
            else
              candle_top    = candle_close
              candle_bottom = candle_open
            end

            highest_top   = candle_top if k == 0
            lowest_bottom = candle_bottom if k == 0
            highest_top   = candle_top if candle_top > highest_top
            lowest_bottom = candle_bottom if candle_bottom < lowest_bottom
          end

          # Average tops and bottoms. # [2..5]
          highest_tops_sum   += highest_top
          lowest_bottoms_sum += lowest_bottom

          # Highest highs and lows. # [2..5]
          highest_high = candles['candles'][i + j + count - 1]['mid']['h'].to_f if candles['candles'][i + j + count - 1]['mid']['h'].to_f > highest_high
          lowest_low   = candles['candles'][i + j + count - 1]['mid']['l'].to_f if candles['candles'][i + j + count - 1]['mid']['l'].to_f < lowest_low
        end

        top_sma    = highest_tops_sum / count
        bottom_sma = lowest_bottoms_sum / count

        @highest_highs                 << highest_high
        @lowest_lows                   << lowest_low
        @top_simple_moving_averages    << top_sma
        @bottom_simple_moving_averages << bottom_sma
        @average_body_sizes            << (top_sma - bottom_sma).round(5)
        @top_shadow_sizes              << (highest_high - top_sma).round(5)
        @bottom_shadow_sizes           << (bottom_sma - lowest_low).round(5)
      end
    end

    def average_body_size
      average_body_sizes[-1 - plotted_ahead]
    end

    def top_shadow_size
      top_shadow_sizes[-1 - plotted_ahead]
    end

    def bottom_shadow_size
      bottom_shadow_sizes[-1 - plotted_ahead]
    end
  end
end

# Average Body Size: (6-period top simple moving average - 6-period bottom simple moving average)
#
# Top Shadow Size: (6-period highest high - 6-period top simple moving average)
#
# Bottom Shadow Size: (6-period bottom simple moving average - 6-period lowest low)
