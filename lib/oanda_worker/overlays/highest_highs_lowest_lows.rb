# Author: Kobus Joubert.
module Overlays
  class HighestHighsLowestLows < Overlay
    REQUIRED_ATTRIBUTES = [:candles, :round_decimal, :pip_size].freeze

    attr_accessor :candles, :count, :plotted_ahead, :round_decimal, :pip_size
    attr_reader   :highest_high, :lowest_low

    def initialize(options = {})
      super
      @count              ||= 300
      @plotted_ahead      ||= 0 # NOTE: Not tested yet.
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count - plotted_ahead
      to                  = from + count - 1
      @candles['candles'] = candles['candles'][from..to]

      @highest_high  = candles['candles'].first['mid']['h'].to_f
      @lowest_low    = candles['candles'].first['mid']['l'].to_f

      candles['candles'].each do |candle|
        @highest_high = candle['mid']['h'].to_f.round(round_decimal) if candle['mid']['h'].to_f.round(round_decimal) > highest_high
        @lowest_low   = candle['mid']['l'].to_f.round(round_decimal) if candle['mid']['l'].to_f.round(round_decimal) < lowest_low
      end
    end
  end
end
