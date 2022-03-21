# Author: Francois Joubert.
module Overlays
  class HighLowChannel < Overlay
    REQUIRED_ATTRIBUTES = [:candles, :key_base, :round_decimal, :pip_size].freeze

    attr_accessor :candles, :count, :plotted_ahead, :channel_box_size, :key_base, :round_decimal, :pip_size
    attr_reader   :highest_highs, :lowest_lows

    def initialize(options = {})
      super
      @count              ||= 500
      @plotted_ahead      ||= 0 # NOTE: Not tested yet.
      @channel_box_size   ||= 20
      @channel_box_size   = channel_box_size * 10
      @key_base           = "#{key_base}:overlays:high_low_channel"
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count - plotted_ahead
      to                  = from + count - 1
      @candles['candles'] = candles['candles'][from..to]

      @highest_highs = []
      @lowest_lows   = []

      highest_high = candles['candles'].first['mid']['h'].to_f
      lowest_low   = candles['candles'].first['mid']['l'].to_f

      candles['candles'].each do |candle|
        highest_high = candle['mid']['h'].to_f if candle['mid']['h'].to_f > highest_high
        lowest_low   = candle['mid']['l'].to_f if candle['mid']['l'].to_f < lowest_low
      end

      # Initialize to down trend.
      unless channel_trend && channel_top_trend && channel_bottom_trend && channel_middle_trend
        self.channel_trend        = :down unless channel_trend
        self.channel_top_trend    = :down unless channel_top_trend
        self.channel_middle_trend = :down unless channel_middle_trend
        self.channel_bottom_trend = :down unless channel_bottom_trend
      end

      # Initialize prises.
      unless channel_top_price && channel_bottom_price && channel_middle_price
        self.channel_top_price    = highest_high unless channel_top_price
        self.channel_bottom_price = lowest_low unless channel_bottom_price

        # Ceil channel middle box price.
        unless channel_middle_price
          channel_average_box_price    = (channel_average / pip_size_increment).round.to_i
          ceiled_channel_average_price = channel_average_box_price - (channel_average_box_price % channel_box_size) + channel_box_size
          self.channel_middle_price    = (ceiled_channel_average_price * pip_size_increment).round(round_decimal)
        end
      end

      # Trend and price checks.
      if highest_high > channel_top_price
        self.channel_top_trend = :up
        self.channel_top_price = highest_high
      end

      if highest_high < channel_top_price
        self.channel_top_trend = :down
        self.channel_top_price = highest_high
      end

      if lowest_low > channel_bottom_price
        self.channel_bottom_trend = :up
        self.channel_bottom_price = lowest_low
      end

      if lowest_low < channel_bottom_price
        self.channel_bottom_trend = :down
        self.channel_bottom_price = lowest_low
      end

      if channel_average >= channel_middle_price
        self.channel_middle_trend = :up
      end

      if channel_average < channel_middle_price
        self.channel_middle_trend = :down
      end

      upper_box_check_price = channel_middle_price + (pip_size_increment * channel_box_size)
      lower_box_check_price = channel_middle_price - (pip_size_increment * channel_box_size)

      if channel_average >= upper_box_check_price
        self.channel_middle_trend     = :up
        channel_average_box_price     = (channel_average / pip_size_increment).round.to_i
        floored_channel_average_price = channel_average_box_price - (channel_average_box_price % channel_box_size)
        self.channel_middle_price     = (floored_channel_average_price * pip_size_increment).round(round_decimal)
      end

      if channel_average < lower_box_check_price
        self.channel_middle_trend    = :down
        channel_average_box_price    = (channel_average / pip_size_increment).round.to_i
        ceiled_channel_average_price = channel_average_box_price - (channel_average_box_price % channel_box_size) + channel_box_size
        self.channel_middle_price    = (ceiled_channel_average_price * pip_size_increment).round(round_decimal)
      end

      self.channel_trend = :up if channel_top_trend == 'up' && channel_bottom_trend == 'up' && channel_middle_trend == 'up'
      self.channel_trend = :down if channel_top_trend == 'down' && channel_bottom_trend == 'down' && channel_middle_trend == 'down'
    end

    # Main channel average.
    def channel_average
      @channel_average ||= begin
        raise OandaWorker::IndicatorError, "#{self.class} ERROR. Need to initialize channel_top_price and channel_bottom_price first." unless channel_top_price && channel_bottom_price
        ((channel_top_price + channel_bottom_price + candles['candles'].last['mid']['c'].to_f) / 3).round(round_decimal)
      end
    end

    # Main channel trend.
    def channel_trend
      $redis.get("#{key_base}:channel_trend")
    end

    def channel_trend=(value)
      $redis.set("#{key_base}:channel_trend", value.to_s)
    end

    def channel_top_trend
      $redis.get("#{key_base}:channel_top_trend")
    end

    def channel_top_trend=(value)
      $redis.set("#{key_base}:channel_top_trend", value.to_s)
    end

    def channel_middle_trend
      $redis.get("#{key_base}:channel_middle_trend")
    end

    def channel_middle_trend=(value)
      $redis.set("#{key_base}:channel_middle_trend", value.to_s)
    end

    def channel_bottom_trend
      $redis.get("#{key_base}:channel_bottom_trend")
    end

    def channel_bottom_trend=(value)
      $redis.set("#{key_base}:channel_bottom_trend", value.to_s)
    end

    def channel_top_price
      $redis.get("#{key_base}:channel_top_price") && $redis.get("#{key_base}:channel_top_price").to_f
    end

    def channel_top_price=(value)
      $redis.set("#{key_base}:channel_top_price", value.to_s)
    end

    def channel_middle_price
      $redis.get("#{key_base}:channel_middle_price") && $redis.get("#{key_base}:channel_middle_price").to_f
    end

    def channel_middle_price=(value)
      $redis.set("#{key_base}:channel_middle_price", value.to_s)
    end

    def channel_bottom_price
      $redis.get("#{key_base}:channel_bottom_price") && $redis.get("#{key_base}:channel_bottom_price").to_f
    end

    def channel_bottom_price=(value)
      $redis.set("#{key_base}:channel_bottom_price", value.to_s)
    end

    def pip_size_increment
      @pip_size_increment ||= pip_size * 0.1
    end
  end
end
