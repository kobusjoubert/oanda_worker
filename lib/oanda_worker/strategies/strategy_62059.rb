module Strategies
  class Strategy62059 < Strategy
    INSTRUMENT       = INSTRUMENTS['EUR_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['EUR_USD']['pip_size'].freeze
    CANDLES_REQUIRED = 1.freeze

    attr_reader :channel_box_size_pips, :channel_box_size_integer, :unit_size_sequence, :unit_size_sequence_index

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @channel_box_size_pips    ||= 15.freeze
      @channel_box_size_integer = (channel_box_size_pips * 10).freeze
      @unit_size_sequence       = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946].freeze
      @unit_size_sequence_index = $redis.get("#{key_base}:unit_size_sequence_index").to_i

      if [1, 2, 6].include?(step)
        candles(smooth: false, include_incomplete_candles: true)
      end

      raise OandaWorker::StrategyStepError, "More than 1 active trade! oanda_active_trades: #{oanda_active_trades.size}" if oanda_active_trades.size > 1

      return false if order_closed_because_of_insufficient_margin? && exit_trades_and_orders! && cleanup && reset_steps
    end

    include Strategies::Steps::Strategy62XX1
  end
end
