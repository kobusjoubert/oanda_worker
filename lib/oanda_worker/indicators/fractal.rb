module Indicators
  class Fractal < Indicator
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead, :center_index, :preceding_candles, :following_candles

    def initialize(options = {})
      super
      @count         ||= 5
      @plotted_ahead ||= 0
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count - plotted_ahead
      to                  = from + count - 1
      @candles['candles'] = candles['candles'][from..to]
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Number of candles must be an odd number. candles: #{candles}; count: #{count}" if count % 2 == 0

      @center_index      = (count.to_f / 2.to_f).floor.freeze
      @preceding_candles = candles['candles'][0..center_index - 1].freeze
      @following_candles = candles['candles'][center_index + 1..-1].freeze
    end

    # Up fractal ^ means the market has reached a significant high indicating a mini reversal for the market to go down.
    # Down fractal ⌄ means the market has reached a significant low indicating a mini reversal for the market to go up.

    # When the 3rd candle's high or low is higher or lower than the previous 2 candles.
    def possible_direction
      return :up if possible_up?
      return :down if possible_down?
      nil
    end

    # When the 5th candle has confirmed a mini reversal.
    def confirmed_direction
      return :up if confirmed_up?
      return :down if confirmed_down?
      nil
    end

    def possible_up?
      candles['candles'].last['mid']['h'].to_f > candles['candles'][center_index..count - 2].map{ |candle| candle['mid']['h'].to_f }.max
    end

    def possible_down?
      candles['candles'].last['mid']['l'].to_f < candles['candles'][center_index..count - 2].map{ |candle| candle['mid']['l'].to_f }.min
    end

    def confirmed_up?
      candles['candles'][center_index]['mid']['h'].to_f > preceding_candles.map{ |candle| candle['mid']['h'].to_f }.max &&
      candles['candles'][center_index]['mid']['h'].to_f > following_candles.map{ |candle| candle['mid']['h'].to_f }.max
    end

    def confirmed_down?
      candles['candles'][center_index]['mid']['l'].to_f < preceding_candles.map{ |candle| candle['mid']['l'].to_f }.min &&
      candles['candles'][center_index]['mid']['l'].to_f < following_candles.map{ |candle| candle['mid']['l'].to_f }.min
    end

    def point
      return candles['candles'][center_index]['mid']['h'].to_f if confirmed_up?
      return candles['candles'][center_index]['mid']['l'].to_f if confirmed_down?
      nil
    end

    def risk_factor
      if possible_up?
        return ((candles['candles'].last['mid']['h'].to_f - candles['candles'][center_index..count - 2].map{ |candle| candle['mid']['l'].to_f }.min).abs * 100).round(5)
      end

      if possible_down?
        return ((candles['candles'].last['mid']['l'].to_f - candles['candles'][center_index..count - 2].map{ |candle| candle['mid']['h'].to_f }.max).abs * 100).round(5)
      end
    end
  end
end

# https://admiralmarkets.com/education/articles/forex-indicators/fractals-indicator
# https://www.investopedia.com/articles/trading/06/fractals.asp
