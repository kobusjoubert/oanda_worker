module Concerns
  module Backtest
    def backtesting
      @backtesting ||= ENV['APP_ENV'] == 'backtest'
    end

    alias :backtesting? :backtesting
  end
end
