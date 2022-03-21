module Overlays
  class ExponentialMovingAverage < Overlay
    REQUIRED_ATTRIBUTES = [:candles_or_values].freeze

    attr_accessor :candles, :values, :sma_values, :count, :plotted_ahead
    attr_reader   :simple_moving_average

    def initialize(options = {})
      super
      @count         ||= 10
      @plotted_ahead ||= 0 # TODO: Not tested yet!
      @values        = candles['candles'].map{ |candle| candle['mid']['c'].to_f } if candles
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. values: #{values}; count: #{count}" if values.empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough values returned, #{count + plotted_ahead} needed. values: #{values.count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if values.count < count + plotted_ahead
      @values     = values.dup
      @sma_values = values.dup
      from        = count
      to          = -1
      @values     = values[from..to]
      sma_from    = 0
      sma_to      = sma_from + count - 1
      @sma_values = sma_values[sma_from..sma_to]

      @simple_moving_average = Overlays::SimpleMovingAverage.new(values: sma_values, count: count).point
    end

    def points
      @points ||= begin
        points              = []
        multiplier          = 2.to_f / (count + 1).to_f
        ema_previous_period = simple_moving_average
        points              << ema_previous_period

        values.each do |value|
          # ema_previous_period = (value - ema_previous_period) * multiplier + ema_previous_period    # [40 period] 0.1943387966083206
          ema_previous_period = (value * multiplier) + ema_previous_period * (1.to_f - multiplier) # [40 period] 0.19433879660832043
          points              << ema_previous_period
        end

        points
      end
    end

    def point
      points[-1 - plotted_ahead]
    end
  end
end

# http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:moving_averages
# http://www.dummies.com/personal-finance/investing/stocks-trading/how-to-calculate-exponential-moving-average-in-trading/
# http://investexcel.net/how-to-calculate-macd-in-excel/
#
# NOTE: The more candles you supply, the more accurate the calculations are.
