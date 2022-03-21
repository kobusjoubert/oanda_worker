module Overlays
  class SimpleMovingAverage < Overlay
    REQUIRED_ATTRIBUTES = [:candles_or_values].freeze

    attr_accessor :candles, :values, :count, :plotted_ahead

    def initialize(options = {})
      super
      @count         ||= 20
      @plotted_ahead ||= 0
      @values        = candles['candles'].map{ |candle| candle['mid']['c'].to_f } if candles
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. values: #{values}; count: #{count}" if values.empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough values returned, #{count + plotted_ahead} needed. values: #{values.count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if values.count < count + plotted_ahead
      @values = values.dup
      from    = values.count - count - plotted_ahead
      to      = from + count - 1
      @values = values[from..to]
    end

    def point
      sum = 0

      values.each do |value|
        sum += value.to_f
      end

      sum / count
    end
  end
end
