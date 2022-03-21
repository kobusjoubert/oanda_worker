module Overlays
  class WeightedMovingAverage < Overlay
    REQUIRED_ATTRIBUTES = [:candles_or_values].freeze

    attr_accessor :candles, :values, :count, :plotted_ahead, :points_count

    def initialize(options = {})
      super
      @count         ||= 20
      @plotted_ahead ||= 0
      @points_count  ||= 1
      @values        = candles['candles'].map{ |candle| candle['mid']['c'].to_f } if candles
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. values: #{values}; count: #{count}" if values.empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough values returned, #{count + plotted_ahead + points_count - 1} needed. values: #{values.count}; count: #{count}; plotted_ahead: #{plotted_ahead}, points_count: #{points_count}" if values.count < count + plotted_ahead + points_count - 1
      @values = values.dup
      from    = values.count - count - points_count + 1
      to      = from + values.count - 1
      @values = values[from..to]
    end

    def points
      @points ||= begin
        points      = []
        denominator = 0

        for i in 1..count
          denominator += i
        end

        for i in 0..(values.count - count)
          point = 0

          values[i..i + count - 1].each_with_index do |value, j|
            point += value * ((j.to_f + 1) / denominator.to_f)
          end

          points << point
        end

        points
      end
    end

    def point
      points[-1 - plotted_ahead]
    end
  end
end

# https://www.oanda.com/forex-trading/learn/forex-indicators/weighted-moving-average
