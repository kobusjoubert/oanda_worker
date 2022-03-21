module Overlays
  class ParabolicStopAndReverse < Overlay
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead, :acceleration_factor, :max_acceleration_factor

    def initialize(options = {})
      super
      @acceleration_factor     ||= 0.02
      @max_acceleration_factor ||= 0.2
      @plotted_ahead           ||= 0
      @count                   ||= candles['candles'].count - plotted_ahead
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count
      @candles = candles.dup
      # from                = candles['candles'].count - count - plotted_ahead
      # to                  = from + count - 1
      # @candles['candles'] = candles['candles'][from..to]
    end

    def points
      @points ||= begin
        points      = []
        trend       = :down
        trend_count = 0

        previous_parabolic_stop_and_reverse = candles['candles'][0]['mid']['h'].to_f
        previous_extreme_point              = candles['candles'][0]['mid']['l'].to_f
        previous_acceleration_factor        = acceleration_factor

        points << previous_parabolic_stop_and_reverse

        candles['candles'].each_with_index do |candle, i|
          next if i == 0

          case trend
          when :down
            trend_count += 1

            if candle['mid']['l'].to_f < previous_extreme_point
              previous_extreme_point       = candle['mid']['l'].to_f
              previous_acceleration_factor = [(previous_acceleration_factor + acceleration_factor), max_acceleration_factor].min unless previous_acceleration_factor >= max_acceleration_factor
            end

            previous_parabolic_stop_and_reverse = previous_parabolic_stop_and_reverse - previous_acceleration_factor * (previous_parabolic_stop_and_reverse - previous_extreme_point)

            if previous_parabolic_stop_and_reverse <= candle['mid']['h'].to_f
              trend                               = :up
              trend_count                         = 0
              previous_parabolic_stop_and_reverse = previous_extreme_point
              previous_extreme_point              = candle['mid']['h'].to_f
              previous_acceleration_factor        = acceleration_factor
            else
              if trend_count == 1 && previous_parabolic_stop_and_reverse < candles['candles'][i - 1]['mid']['h'].to_f
                previous_parabolic_stop_and_reverse = candles['candles'][i - 1]['mid']['h'].to_f
              end

              if trend_count > 1 && previous_parabolic_stop_and_reverse < [candles['candles'][i - 1]['mid']['h'].to_f, candles['candles'][i - 2]['mid']['h'].to_f].max
                previous_parabolic_stop_and_reverse = [candles['candles'][i - 1]['mid']['h'].to_f, candles['candles'][i - 2]['mid']['h'].to_f].max
              end
            end
          when :up
            trend_count += 1

            if candle['mid']['h'].to_f > previous_extreme_point
              previous_extreme_point       = candle['mid']['h'].to_f
              previous_acceleration_factor = [(previous_acceleration_factor + acceleration_factor), max_acceleration_factor].min unless previous_acceleration_factor >= max_acceleration_factor
            end

            previous_parabolic_stop_and_reverse = previous_parabolic_stop_and_reverse + previous_acceleration_factor * (previous_extreme_point - previous_parabolic_stop_and_reverse)

            if previous_parabolic_stop_and_reverse >= candle['mid']['l'].to_f
              trend                               = :down
              trend_count                         = 0
              previous_parabolic_stop_and_reverse = previous_extreme_point
              previous_extreme_point              = candle['mid']['l'].to_f
              previous_acceleration_factor        = acceleration_factor
            else
              if trend_count == 1 && previous_parabolic_stop_and_reverse > candles['candles'][i - 1]['mid']['l'].to_f
                previous_parabolic_stop_and_reverse = candles['candles'][i - 1]['mid']['l'].to_f
              end

              if trend_count > 1 && previous_parabolic_stop_and_reverse > [candles['candles'][i - 1]['mid']['l'].to_f, candles['candles'][i - 2]['mid']['l'].to_f].min
                previous_parabolic_stop_and_reverse = [candles['candles'][i - 1]['mid']['l'].to_f, candles['candles'][i - 2]['mid']['l'].to_f].min
              end
            end
          end

          points << previous_parabolic_stop_and_reverse
        end

        points
      end
    end

    def point
      points[-1 - plotted_ahead]
    end
  end
end

# https://www.tradinformed.com/calculate-psar-indicator-revised/
# https://www.tradingview.com/wiki/Parabolic_SAR_(SAR)
# http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:parabolic_sar
# https://en.wikipedia.org/wiki/Parabolic_SAR
#
# Previous SAR: The SAR value for the previous period
# Extreme Point (EP): The highest high of the current uptrend or the lowest low of the current downtrend
# Acceleration Factor (AF): Determines the sensitivity of the SAR, starts at .02 and increases by .02 every time the EP rises in a Rising SAR or EP falls in a Falling SAR
#
# The calculations for Rising Parabolic SAR and Falling Parabolic SAR are different so they will be separated
#
# Rising Parabolic SAR:
# Current SAR = Previous SAR + Previous AF(Previous EP - Previous SAR)
#
# Falling Parabolic SAR:
# Current SAR = Previous SAR - Previous AF(Previous SAR - Previous EP)
#
#
# SARn+1 = SARn + AF(EP - SARn)
# where SARn and SARn+1 represent the current period and the next period's SAR values, respectively.
#
# The SAR is calculated in this manner for each new period. However, two special cases will modify the SAR value:
# - If the next period’s SAR value is inside (or beyond) the current period or the previous period’s price range, the SAR must be set to the closest price
#   bound. For example, if in an upward trend, the new SAR value is calculated and if it results to be more than today’s or yesterday’s lowest price, it
#   must be set equal to that lower boundary.
# - If the next period’s SAR value is inside (or beyond) the next period’s price range, a new trend direction is then signaled. The SAR must then switch
#   sides. Upon a trend switch, the first SAR value for this new trend is set to the last EP recorded on the prior trend, EP is then reset accordingly to this
#   period’s maximum, and the acceleration factor is reset to its initial value of 0.02.
#
# NOTE: The more candles you supply, the more accurate the calculations are.
