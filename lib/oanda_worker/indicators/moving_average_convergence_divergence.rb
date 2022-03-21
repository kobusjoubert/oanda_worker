module Indicators
  class MovingAverageConvergenceDivergence < Indicator
    REQUIRED_ATTRIBUTES = [:candles_or_values].freeze

    attr_accessor :candles, :values, :fast_period_count, :slow_period_count, :trigger_period_count, :plotted_ahead
    attr_reader   :fast_exponential_moving_averages, :slow_exponential_moving_averages, :trigger_exponential_moving_averages

    def initialize(options = {})
      super
      @fast_period_count    ||= 12
      @slow_period_count    ||= 26
      @trigger_period_count ||= 9
      @plotted_ahead        ||= 0
      @values               = candles['candles'].map{ |candle| candle['mid']['c'].to_f } if candles
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. values: #{values}" if values.empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough values returned, #{[fast_period_count, slow_period_count, trigger_period_count].max + plotted_ahead} needed. values: #{values.count}; fast_period_count: #{fast_period_count}; slow_period_count: #{slow_period_count}; trigger_period_count: #{trigger_period_count}; plotted_ahead: #{plotted_ahead}" if values.count < [fast_period_count, slow_period_count, trigger_period_count].max + plotted_ahead
      @values = values.dup

      @fast_exponential_moving_averages    = Overlays::ExponentialMovingAverage.new(values: values, count: fast_period_count).points
      @slow_exponential_moving_averages    = Overlays::ExponentialMovingAverage.new(values: values, count: slow_period_count).points
      @trigger_exponential_moving_averages = Overlays::ExponentialMovingAverage.new(values: macd_line_points, count: trigger_period_count).points
    end

    def macd_line_points
      @macd_line_points ||= begin
        points      = []
        fema_offset = slow_period_count - fast_period_count

        slow_exponential_moving_averages.each_with_index do |sema, i|
          points << fast_exponential_moving_averages[fema_offset + i] - sema
        end

        points
      end
    end

    # Oanda app does not show this line yet, the app is a bit slow. To see what the app is displaying set plotted_ahead to 1.
    def macd_line_point
      macd_line_points[-1 - plotted_ahead]
    end

    def signal_line_points
      trigger_exponential_moving_averages
    end

    # Oanda app does not show this line yet, the app is a bit slow. To see what the app is displaying set plotted_ahead to 1.
    def signal_line_point
      signal_line_points[-1 - plotted_ahead]
    end

    def macd_histogram_point
      macd_line_point - signal_line_point
    end
  end
end

# http://investexcel.net/how-to-calculate-macd-in-excel/
# http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:moving_average_convergence_divergence_macd
# MACD Line: (12-day EMA - 26-day EMA)
# Signal Line: 9-day EMA of MACD Line
# MACD Histogram: MACD Line - Signal Line
#
# NOTE: The more candles you supply, the more accurate the calculations are.
