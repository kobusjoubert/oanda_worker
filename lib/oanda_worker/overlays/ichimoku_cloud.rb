module Overlays
  class IchimokuCloud < Overlay
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :tenkan_sen_count, :kijun_sen_count, :senkou_span_b_count, :plotted_ahead

    def initialize(options = {})
      super
      @tenkan_sen_count    ||= 9
      @kijun_sen_count     ||= 26
      @senkou_span_b_count ||= 52
      @chikou_span         ||= 0
      @plotted_ahead       ||= 26
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{[tenkan_sen_count, kijun_sen_count, senkou_span_b_count].max + plotted_ahead} needed. candles: #{candles['candles'].count}; tenkan_sen_count: #{tenkan_sen_count}; kijun_sen_count: #{kijun_sen_count}; senkou_span_b_count: #{senkou_span_b_count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < [tenkan_sen_count, kijun_sen_count, senkou_span_b_count].max + plotted_ahead
      @candles = candles.dup
    end

    def tenkan_sen_point
      Indicators::Donchian.new(candles: candles, count: tenkan_sen_count, plotted_ahead: plotted_ahead).point
    end

    def kijun_sen_point
      Indicators::Donchian.new(candles: candles, count: kijun_sen_count, plotted_ahead: plotted_ahead).point
    end

    def senkou_span_a
      (kijun_sen_point + tenkan_sen_point) / 2
    end

    def senkou_span_b
      Indicators::Donchian.new(candles: candles, count: senkou_span_b_count, plotted_ahead: plotted_ahead).point
    end

    # TODO: Implement if ever going to be used.
    def chikou_span
      chikou_span
    end
  end
end

# http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:ichimoku_cloud
#
# Tenkan-sen (Conversion Line): (9-period high + 9-period low)/2))
# The default setting is 9 periods and can be adjusted. On a daily chart, this line is the mid point of the 9 day high-low range, which is almost two weeks.
#
# Kijun-sen (Base Line): (26-period high + 26-period low)/2))
# The default setting is 26 periods and can be adjusted. On a daily chart, this line is the mid point of the 26 day high-low range, which is almost one 
# month.
#
# Senkou Span A (Leading Span A): (Conversion Line + Base Line)/2))
# This is the midpoint between the Conversion Line and the Base Line. The Leading Span A forms one of the two Cloud boundaries. It is referred to as "Leading"
# because it is plotted 26 periods in the future and forms the faster Cloud boundary.
#
# Senkou Span B (Leading Span B): (52-period high + 52-period low)/2))
# On the daily chart, this line is the mid point of the 52 day high-low range, which is a little less than 3 months. The default calculation setting is 52
# periods, but can be adjusted. This value is plotted 26 periods in the future and forms the slower Cloud boundary.
#
# Chikou Span (Lagging Span): Close plotted 26 days in the past
# The default setting is 26 periods, but can be adjusted.
