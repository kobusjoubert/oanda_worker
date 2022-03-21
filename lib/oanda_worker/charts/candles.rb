module Charts
  class Candles < Chart
    REQUIRED_ATTRIBUTES = [:oanda_client, :instrument].freeze

    attr_accessor :oanda_client, :instrument, :granularity, :chart_interval, :smooth, :count, :from, :to, :price, :include_incomplete_candles

    def initialize(options = {})
      super
      @count                      ||= 100 # FIXME attr_reader count does not return @count in function chart?
      @chart_interval             ||= 60
      @smooth                     ||= false
      @include_incomplete_candles ||= false
      @price                      ||= 'M'
      @granularity                ||= Definitions::Instrument.candlestick_granularity(chart_interval)
      @from                       = Time.new.api(from.utc) if from
      @to                         = Time.new.api(to.utc) if to
    end

    def chart
      options = { granularity: granularity, price: price, smooth: smooth }

      if from && to
        options[:from]  = from
        options[:to]    = to
        @count          = 0
      else
        # NOTE:
        #
        # Oanda API does not have an option to return only complete candles. The last candle will almost always be an incomplete candle that hasn't closed yet.
        # So when we want to only have complete candles, we have to ask for an extra candle and remove the last candle if it is not complete at the time we requested it.
        #
        # By default we don't want to have incomplete candles because the indicators and overlays require complete candles most of the time.
        #
        # When backtesting, we will use the last complete candle in any indicators, as well as use it as the current_candle.
        options[:count] = include_incomplete_candles ? @count : @count + 1
      end

      candles = oanda_client.instrument(instrument).candles(options).show

      unless from && to
        candles['candles'].last['complete'] ? candles['candles'].shift : candles['candles'].pop unless include_incomplete_candles
      end

      raise OandaWorker::ChartError, "#{self.class} #{instrument} ERROR. No candles returned. candles: #{candles}; options: #{options}" if candles['candles'].empty?
      raise OandaWorker::ChartError, "#{self.class} #{instrument} ERROR. Not enough candles returned, #{@count} needed. candles: #{candles['candles'].count}; options: #{options}" if candles['candles'].count < @count
      candles
    end
  end
end
