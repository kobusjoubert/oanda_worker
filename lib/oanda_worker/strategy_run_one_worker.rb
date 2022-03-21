class StrategyRunOneWorker
  include Sneakers::Worker
  from_queue :qw_strategy_run_one, arguments: { 'x-max-priority' => 10, 'x-priority' => 10 }, timeout_job_after: 10

  def work(msg)
    data = JSON.parse(msg)

    # Allow qw_strategy_run_all to carry on after job is done.
    if StrategyRun.new(data).send(data[:action])
      $redis.del('backtest:qw_strategy_run_one') if backtesting?
      ack!
    else
      requeue!
    end
  rescue Timeout::Error
    data[:strategies].each do |strategy|
      $redis.del("#{data[:key_base]}:#{strategy}:step_locks")
    end

    Sneakers.logger.error "TIMEOUT ERROR! data. #{data}"
    requeue!
  end
end
