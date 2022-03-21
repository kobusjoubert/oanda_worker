module Indicators
  class Donchian < Indicator
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead

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
    end

    def point
      highest_high = candles['candles'].first['mid']['h'].to_f
      lowest_low   = candles['candles'].first['mid']['l'].to_f

      candles['candles'].each do |candle|
        highest_high = candle['mid']['h'].to_f if candle['mid']['h'].to_f > highest_high
        lowest_low   = candle['mid']['l'].to_f if candle['mid']['l'].to_f < lowest_low
      end

      (highest_high + lowest_low) / 2
    end
  end
end
