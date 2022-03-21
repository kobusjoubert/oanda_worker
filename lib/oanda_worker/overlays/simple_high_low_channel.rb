# Author: Francois Joubert.
module Overlays
  class SimpleHighLowChannel < Overlay
    REQUIRED_ATTRIBUTES = [:candles, :key_base, :round_decimal, :pip_size].freeze

    attr_accessor :candles, :count, :plotted_ahead, :smoothed_count, :key_base, :round_decimal, :pip_size
    attr_reader   :highest_highs, :lowest_lows, :highest_high, :lowest_low

    def initialize(options = {})
      super
      @count              ||= 288
      @plotted_ahead      ||= 0 # NOTE: Not tested yet.
      @key_base         = "#{key_base}:overlays:simple_high_low_channel"
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count - plotted_ahead
      to                  = from + count - 1
      @candles['candles'] = candles['candles'][from..to]

      @highest_highs = []
      @lowest_lows   = []
      @highest_high  = candles['candles'].first['mid']['h'].to_f
      @lowest_low    = candles['candles'].first['mid']['l'].to_f

      candles['candles'].each do |candle|
        @highest_high = candle['mid']['h'].to_f if candle['mid']['h'].to_f > @highest_high
        @lowest_low   = candle['mid']['l'].to_f if candle['mid']['l'].to_f < @lowest_low
      end

      # Initialize prises.
      unless channel_top_price && channel_bottom_price
        self.channel_top_price    = @highest_high unless channel_top_price
        self.channel_bottom_price = @lowest_low unless channel_bottom_price
      end
    end

    def channel_top_breakout?
      highest_high > previous_channel_top_price && !channel_bottom_breakout?
    end

    def channel_bottom_breakout?
      lowest_low < previous_channel_bottom_price && !channel_top_breakout?
    end

    def channel_top_and_bottom_breakout?
      highest_high > previous_channel_top_price && lowest_low < previous_channel_bottom_price
    end

    # Only run this once all strategy logic checks has been completed at last step needing these values.
    def update_channel_prices!
      self.channel_top_price    = highest_high if channel_top_breakout?
      self.channel_bottom_price = lowest_low if channel_bottom_breakout?

      if channel_top_and_bottom_breakout?
        self.channel_top_price    = highest_high
        self.channel_bottom_price = lowest_low
      end

      true
    end

    def channel_top_price
      $redis.get("#{key_base}:channel_top_price") && $redis.get("#{key_base}:channel_top_price").to_f
    end

    def channel_top_price=(value)
      $redis.set("#{key_base}:channel_top_price", value.to_s)
    end

    def channel_bottom_price
      $redis.get("#{key_base}:channel_bottom_price") && $redis.get("#{key_base}:channel_bottom_price").to_f
    end

    def channel_bottom_price=(value)
      $redis.set("#{key_base}:channel_bottom_price", value.to_s)
    end

    def channel_size
      (channel_top_price - channel_bottom_price).abs.round(round_decimal)
    end

    # TODO: Finish! Look at Overlays::ExhaustionMovingAverage for reference.
    def smoothed_channel_size
      
    end

    alias :previous_channel_top_price :channel_top_price
    alias :previous_channel_bottom_price :channel_bottom_price
  end
end
