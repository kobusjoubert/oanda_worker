module Strategies
  class Strategy10930 < Strategy
    INSTRUMENT       = INSTRUMENTS['WTICO_USD']['instrument'].freeze
    PIP_SIZE         = INSTRUMENTS['WTICO_USD']['pip_size'].freeze
    CANDLES_REQUIRED = Predictions::WTICOUSDM1::CANDLES_REQUIRED.freeze

    attr_reader :take_profit, :stop_loss, :ml_difference, :pips_required, :round_decimal,
                :prediction_interval_on_won, :prediction_interval_on_lost, :prediction_interval_on_exit, :prediction_candles_required

    def initialize(options = {})
      super
      options.symbolize_keys!

      options.each do |key, value|
        self.send("#{key}=", value) if self.respond_to?("#{key}=")
      end

      @take_profit   = (9.8 * PIP_SIZE).freeze
      @stop_loss     = (16.8 * PIP_SIZE).freeze
      @ml_difference = (28.0 * PIP_SIZE).freeze # The count of the 2 values at the sides of the end of the bell shape divided by 2.
      @pips_required = (ml_difference + take_profit).freeze

      # After a winning trade, wait for 20 candles since the last prediction was requested before requesting for a new prediction.
      # After a losing trade, wait for 60 candles since the last prediction was requested before requesting for a new prediction.
      @prediction_interval_on_won  = 20
      @prediction_interval_on_lost = prediction_interval_on_won * 3
      @prediction_interval_on_exit = prediction_interval_on_won * 4
      @prediction_candles_required = CANDLES_REQUIRED
    end

    include Strategies::Steps::StrategyML
  end
end
