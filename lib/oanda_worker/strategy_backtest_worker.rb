class StrategyBacktestWorker
  include Sneakers::Worker
  from_queue :qw_strategy_backtest, timeout_job_after: 3600

  def work(msg)
    data = JSON.parse(msg)
    StrategyBacktest.new(data).send(data[:action]) ? ack! : requeue!
  end
end
