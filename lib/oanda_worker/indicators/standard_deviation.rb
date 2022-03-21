module Indicators
  class StandardDeviation < Indicator
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead, :simple_moving_average

    def initialize(options = {})
      super
      @count         ||= 20
      @plotted_ahead ||= 0
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count - plotted_ahead
      to                  = from + count - 1
      @candles['candles'] = candles['candles'][from..to]

      @simple_moving_average ||= Overlays::SimpleMovingAverage.new(candles: candles, count: count).point
    end

    def point
      sum = 0

      candles['candles'].each do |candle|
        sum += (candle['mid']['c'].to_f - simple_moving_average) ** 2
      end

      variance = sum / count
      Math.sqrt(variance)
    end
  end
end
