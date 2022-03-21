module Indicators
  class AverageTrueRange < Indicator
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead, :decimal_points

    def initialize(options = {})
      super
      @count          ||= 14
      @plotted_ahead  ||= 0 # TODO: Not implemented yet!
      @decimal_points ||= 4
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count * 2 + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count * 2 + plotted_ahead
      @candles            = candles.dup
      from                = candles['candles'].count - count * 2 - plotted_ahead
      to                  = from + count * 2 - 1 + plotted_ahead
      @candles['candles'] = candles['candles'][from..to]
    end

    def points
      @points ||= begin
        average_true_range_total = 0
        true_range_total         = 0
        points                   = []

        # The starting point and first true range value is simply the high minus the low.
        true_range       = (candles['candles'][0]['mid']['h'].to_f - candles['candles'][0]['mid']['l'].to_f).abs
        true_range_total += true_range

        # The very first calculation for the first average true range is calculated on the average of the first 14-period true ranges.
        for i in 1..(count - 1)
          current_high     = candles['candles'][i]['mid']['h'].to_f
          current_low      = candles['candles'][i]['mid']['l'].to_f
          previous_close   = candles['candles'][i - 1]['mid']['c'].to_f
          true_range       = [(current_high - current_low).abs, (current_high - previous_close).abs, (current_low - previous_close).abs].max
          true_range_total += true_range
        end

        prior_average_true_range = (true_range_total / count)

        # Smooth the data by incorporating the previous period's average true range value.
        for i in count..(count * 2 - 1)
          current_high   = candles['candles'][i]['mid']['h'].to_f
          current_low    = candles['candles'][i]['mid']['l'].to_f
          previous_close = candles['candles'][i - 1]['mid']['c'].to_f
          true_range     = [(current_high - current_low).abs, (current_high - previous_close).abs, (current_low - previous_close).abs].max

          average_true_range       = (prior_average_true_range * (count - 1) + true_range) / count
          prior_average_true_range = average_true_range
        end

        points << prior_average_true_range.round(decimal_points)

        # TODO: Add plotted_ahead points to the points array.

        points
      end
    end

    def point
      points[-1 - plotted_ahead]
    end
  end
end

# https://www.thebalance.com/how-average-true-range-atr-can-improve-trading-4154923
# https://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:average_true_range_atr
#
# Wilder started with a concept called True Range (TR), which is defined as the greatest of the following:
#
#   Method 1: Current High less the current Low
#   Method 2: Current High less the previous Close (absolute value)
#   Method 3: Current Low less the previous Close (absolute value)
#
# Typically, the Average True Range (ATR) is based on 14 periods and can be calculated on an intraday, daily, weekly or monthly basis. For this example, the ATR will be based on daily data. 
# Because there must be a beginning, the first TR value is simply the High minus the Low, and the first 14-day ATR is the average of the daily TR values for the last 14 days.
# After that, Wilder sought to smooth the data by incorporating the previous period's ATR value.
#
# Current ATR = [(Prior ATR x 13) + Current TR] / 14
