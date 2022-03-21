class StrategyRunAllWorker
  include Sneakers::Worker
  # The timeout_job_after value should not be greater than the strategy_clock_scheduler interval. The workers could fall behind!
  from_queue :qw_strategy_run_all, timeout_job_after: 30

  def work(msg)
    data = JSON.parse(msg)

    # Wait a maximum of 6 seconds for qw_strategy_run_one to finish before carrying on when backtesting.
    # TODO: We could use this logic for the live system as well.
    #       It would need to be more specific to a user account and strategy though.
    #       Also consider that this could cause a backlog of queued messages.
    if backtesting?
      for i in 1..4
        if $redis.get('backtest:qw_strategy_run_one')
          return ack! if i == 4
          sleep i
        else
          break
        end
      end
    end

    StrategyRun.new(data).send(data[:action]) ? ack! : requeue!
  rescue Timeout::Error
    data[:strategies].each do |strategy|
      $redis.del("#{data[:key_base]}:#{strategy}:step_locks")
    end

    Sneakers.logger.error "TIMEOUT ERROR! data. #{data}"
    requeue!
  end
end
