module Indicators
  class RelativeStrengthIndex < Indicator
    REQUIRED_ATTRIBUTES = [:candles].freeze

    attr_accessor :candles, :count, :plotted_ahead

    def initialize(options = {})
      super
      @count         ||= 14
      @plotted_ahead ||= 0
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No candles to work with. candles: #{candles}; count: #{count}" if candles['candles'].empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough candles returned, #{count + plotted_ahead} needed. candles: #{candles['candles'].count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if candles['candles'].count < count + plotted_ahead
      @candles = candles.dup
    end

    def points
      @points ||= begin
        points = []

        # The very first calculations for average gain and average loss are simple 14-period averages.
        up_movements   = [0.to_f]
        down_movements = [0.to_f]

        # candles['candles'][0..count - 1].each_with_index do |candle, i|
        for i in 0..(count - 1)
          movement  = i == 0 ? 0.to_f : candles['candles'][i]['mid']['c'].to_f - candles['candles'][i - 1]['mid']['c'].to_f
          direction = movement >= 0 ? :up : :down

          case direction
          when :up
            up_movements << movement
          when :down
            down_movements << movement.abs
          end
        end

        previous_average_gain = up_movements.reduce(:+).to_f / count.to_f
        previous_average_loss = down_movements.reduce(:+).to_f / count.to_f

        relative_strenght_index = 0.to_f if previous_average_gain == 0
        relative_strenght_index = 100.to_f if previous_average_loss == 0

        unless relative_strenght_index
          relative_strength_factor = previous_average_gain / previous_average_loss
          relative_strenght_index  = 100 - 100 / (1 + relative_strength_factor)
        end

        points << relative_strenght_index

        return points unless candles['candles'].count > count

        # The second, and subsequent, calculations are based on the prior averages and the current gain loss.
        for i in count..candles['candles'].count - 1
          movement  = candles['candles'][i]['mid']['c'].to_f - candles['candles'][i - 1]['mid']['c'].to_f
          direction = movement >= 0 ? :up : :down

          case direction
          when :up
            current_gain = movement
            current_loss = 0.to_f
          when :down
            current_loss = movement.abs
            current_gain = 0.to_f
          end

          previous_average_gain = (previous_average_gain * (count - 1) + current_gain) / count
          previous_average_loss = (previous_average_loss * (count - 1) + current_loss) / count

          relative_strenght_index = nil
          relative_strenght_index = 0.to_f if previous_average_gain == 0
          relative_strenght_index = 100.to_f if previous_average_loss == 0

          unless relative_strenght_index
            relative_strength_factor = previous_average_gain / previous_average_loss
            relative_strenght_index  = 100 - 100 / (1 + relative_strength_factor)
          end

          points << relative_strenght_index
        end

        points
      end
    end

    def point
      points[-1 - plotted_ahead]
    end
  end
end

# http://www.investopedia.com/terms/r/rsi.asp
# http://www.investopedia.com/articles/technical/071601.asp
#
# RSI = 100 - 100 / (1 + RS)
# RS = Average of 14 days up closes / Average of 14 days down closes
# RS = Average gain of up periods during the specified time frame / Average loss of down periods during the specified time frame
#
# NOTE: Sudden large price movements can create false buy or sell signals in the RSI. It is, therefore, best used with refinements to its application or in conjunction with other, confirming technical indicators.
#
# http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:relative_strength_index_rsi
#
# The very first calculations for average gain and average loss are simple 14-period averages.
#
# First Average Gain = Sum of Gains over the past 14 periods / 14.
# First Average Loss = Sum of Losses over the past 14 periods / 14
# The second, and subsequent, calculations are based on the prior averages and the current gain loss:
#
# Average Gain = [(previous Average Gain) x 13 + current Gain] / 14.
# Average Loss = [(previous Average Loss) x 13 + current Loss] / 14.
#
# NOTE: The more candles you supply, the more accurate the calculations are.
#   250 candles is a good range.
