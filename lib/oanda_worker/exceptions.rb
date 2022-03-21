module OandaWorker
  class Error < StandardError; end
  class RecordNotFound < Error; end
  class ZeroNotAllowed < Error; end
  class ChartError < Error; end
  class IndicatorError < Error; end
  class StrategyError < Error; end
  class StrategyStepError < Error; end
  class PredictionError < Error; end
  class BacktestError < Error; end
end
