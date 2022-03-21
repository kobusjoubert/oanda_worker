module Overlays
  class BollingerBands < Overlay
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :deviation, :plotted_ahead
    attr_reader   :simple_moving_average, :standard_deviation

    def initialize(options = {})
      super
      @deviation     ||= 2
      @count         ||= 20
      @plotted_ahead ||= 0
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles = candles.dup

      @simple_moving_average = Overlays::SimpleMovingAverage.new(candles: candles, count: count, plotted_ahead: plotted_ahead).point
      @standard_deviation    = Indicators::StandardDeviation.new(candles: candles, count: count, plotted_ahead: plotted_ahead, simple_moving_average: simple_moving_average).point
    end

    def middle_band
      simple_moving_average
    end

    def upper_band
      simple_moving_average + standard_deviation * deviation
    end

    def lower_band
      simple_moving_average - standard_deviation * deviation
    end
  end
end
