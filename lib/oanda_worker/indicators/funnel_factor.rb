# Author: Kobus Joubert.
#
# Determine relevancy of the latest volatility in the market by factoring in previous volatility over a period of time.
# The further the sections are away from the current time, the less relevant the volatility.
# This should give us a more aggressive value when the market has been volatile lately.
#
# Example:
#
#   Use 12 months or equal sections in the market.
#   Normalise the sections by converting the highest value up or down to 1.
#   The factor used to convert the highest value are then used to determine the remaining normalised values.
#   Sum all the values and divide by the size of the array.
module Indicators
  class FunnelFactor < Indicator
    REQUIRED_ATTRIBUTES = [:candles_or_values].freeze

    attr_accessor :candles, :values, :count, :plotted_ahead, :risk_factor_weight, :deteriorate_to
    attr_reader   :deteriation_factor

    def initialize(options = {})
      super
      @count              ||= values.size if values
      @count              ||= 12
      @plotted_ahead      ||= 0 # TODO: Not tested yet!
      @values             ||= []
      @risk_factor_weight ||= 0.5 # 0.0..1.0
      @deteriorate_to     ||= 0.5 # 0.0..1.0
      @deteriation_factor = (1 - @deteriorate_to) / count

      if candles
        section_size      = (candles['candles'].size / count).floor
        candles_to_remove = candles['candles'].size - count * section_size
        candles['candles'].shift(candles_to_remove)

        count.times do |i|
          highest_high = candles['candles'][i * section_size]['mid']['h'].to_f
          lowest_low   = candles['candles'][i * section_size]['mid']['l'].to_f

          candles['candles'][i * section_size..(i + 1) * section_size - 1].each do |candle|
            highest_high = candle['mid']['h'].to_f if candle['mid']['h'].to_f > highest_high
            lowest_low   = candle['mid']['l'].to_f if candle['mid']['l'].to_f < lowest_low
          end

          @values << (highest_high - lowest_low).abs
        end
      end

      raise OandaWorker::IndicatorError, "#{self.class} ERROR. No values to work with. values: #{values}; count: #{count}" if values.empty?
      raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough values returned, #{count + plotted_ahead} needed. values: #{values.count}; count: #{count}; plotted_ahead: #{plotted_ahead}" if values.count < count + plotted_ahead
      @values = values.dup
      from    = values.count - count - plotted_ahead
      to      = from + count - 1
      @values = values[from..to]
    end

    # Normalises the values to be in a range between 0 and 1.
    def normalised_values
      normalise_factor = 1.0 / values.max.to_f
      values.map{ |value| normalise_factor * value }
    end

    # Deteriates the normalised values.
    def deteriated_values
      deteriated_values = []

      normalised_values.each_with_index do |value, i|
        deteriated_values << value * (deteriorate_to + deteriation_factor * i)
      end

      deteriated_values
    end

    # Value between 0.0..1.0
    def factor
      funnel_sum     = deteriated_values.inject(0){ |sum, value| sum + value }
      funnel_average = funnel_sum / count
      risk_section   = normalised_values.last * risk_factor_weight
      (funnel_average + risk_section) / 2
    end
  end
end
