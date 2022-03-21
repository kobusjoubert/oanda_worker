class StrategyStep
  REQUIRED_ATTRIBUTES        = [:key_base].freeze
  REQUIRED_CONFIG_ATTRIBUTES = [:chart_interval, :units, :trade_from, :trade_to].freeze
  BACKTEST_ERRORS_TO_IGNORE  = [OandaServiceApi::RequestError, DRb::DRbConnError] if backtesting?

  attr_accessor :oanda_client, :oanda_service_client, :aws_client, :key_base, :backtest_index, :backtest_time
  attr_reader   :status, :step, :config, :max_concurrent_trades, :consecutive_wins, :consecutive_losses,
                :last_transaction_id, :last_ran_at, :last_prediction, :last_prediction_requested_at,
                :account_key_base, :practice, :practice_or_live, :account, :strategy

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end

    @practice_or_live  = key_base.split(':')[0]
    @account           = key_base.split(':')[2]
    @strategy          = key_base.split(':')[4]
    @practice          = practice_or_live == 'practice' ? true : false
    @account_key_base  = key_base.split(':')[0..2].join(':')

    $redis.pipelined do
      @status                       = $redis.get("#{key_base}:status")
      @step                         = $redis.get("#{key_base}:step")
      @config                       = $redis.get("#{key_base}:config")
      @last_ran_at                  = $redis.get("#{key_base}:last_ran_at")
      @consecutive_wins             = $redis.get("#{key_base}:consecutive_wins")
      @consecutive_losses           = $redis.get("#{key_base}:consecutive_losses")
      @last_prediction              = $redis.get("#{key_base}:last_prediction")
      @last_prediction_requested_at = $redis.get("#{key_base}:last_prediction_requested_at")
      @last_transaction_id          = $redis.get("#{key_base}:last_transaction_id")
      @max_concurrent_trades        = $redis.get("#{account_key_base}:max_concurrent_trades")
    end

    @status                       = @status.value
    @step                         = @step.value.to_i
    @config                       = JSON.parse(@config.value).symbolize_keys
    @max_concurrent_trades        = @max_concurrent_trades.value.to_i
    @last_ran_at                  = @last_ran_at.value ? Time.parse(@last_ran_at.value).utc : nil
    @consecutive_wins             = @consecutive_wins.value.to_i
    @consecutive_losses           = @consecutive_losses.value.to_i
    @last_prediction              = @last_prediction.value ? @last_prediction.value.to_f : nil
    @last_prediction_requested_at = @last_prediction_requested_at.value ? Time.parse(@last_prediction_requested_at.value).utc : nil
    @last_transaction_id          = @last_transaction_id.value

    if backtesting? && !backtest_time.instance_of?(Time)
      begin
        @backtest_time = Time.parse(backtest_time).utc
      rescue ArgumentError, TypeError
        @backtest_time = Time.at(backtest_time.to_i).utc
      end
    end

    @oanda_service_client ||= begin
      oanda_service_options = {
        email:                'oanda_worker@translate3d.com',
        authentication_token: ENV['OANDA_SERVICE_AUTHENTICATION_TOKEN'],
        environment:          ENV['APP_ENV'] || 'development'
      }

      oanda_service_options.merge!(backtest_time: backtest_time.iso8601(9)) if backtesting?
      OandaServiceApi.new(oanda_service_options)
    end

    unless oanda_client
      if backtesting?
        @oanda_client   = OandaApiV20Backtest.new(backtest_index: backtest_index, backtest_time: backtest_time)
      else
        @worker_account = Account.find_by!(practice: practice, account: account)
        @oanda_client   = OandaApiV20.new(access_token: @worker_account.access_token, practice: @worker_account.practice)
      end
    end

    @last_transaction_id = oanda_client.account(account).summary.show['lastTransactionID'] unless last_transaction_id
    @aws_client          ||= Aws::MachineLearning::Client.new

    missing_config_attributes = REQUIRED_CONFIG_ATTRIBUTES - config.keys
    raise ArgumentError, "The #{missing_config_attributes} config attributes are missing from the redis key '#{key_base}:config'" unless missing_config_attributes.empty?
  end

  # Runs strategy for account at specified step with config only when not paused.
  def run_strategy_at_step
    begin
      return true if ['paused', 'halted'].include?(status)
      now    = time_now_utc
      minute = now.hour * 60 + now.min

      # Backtesting candles sometimes have candles closing later or opening earlier in the week.
      #
      # Example: EUR_USD H4
      #
      #   Friday's last candle: 2008-09-26T17:00
      #   Sunday's first candle: 2008-09-28T17:00
      unless backtesting?
        return true if time_between_market_close_friday_at_and_market_open_sunday_at?(now, minute)
      end

      trade_from     = Time.parse(config[:trade_from]).utc
      trade_to       = Time.parse(config[:trade_to]).utc
      exit_friday_at = Time.parse(config[:exit_friday_at]).utc if config[:exit_friday_at]

      lock!

      update_backtest_progress_bar if backtesting?

      if exit_friday_at
        # Temporary halt strategies over weekends.
        if status == 'started' && exit_friday_at
          if time_between_exit_friday_at_and_market_open_sunday_at?(now, minute, exit_friday_at)
            temporary_exit_strategy
            unlock!
            return true
          end
        end

        # Resume strategies after weekends.
        if status == 'temporary_halted' && !max_concurrent_trades_reached?
          if time_between_exit_friday_at_and_market_open_sunday_at?(now, minute, exit_friday_at)
            unlock!
            return true
          else
            unlock!
            resume_strategy
          end
        end
      end

      unless trade_from == trade_to
        if trade_to <= trade_from
          if minute < trade_from.hour * 60 + trade_from.min && minute >= trade_to.hour * 60 + trade_to.min
            unlock!
            return true
          end
        else
          if minute < trade_from.hour * 60 + trade_from.min || minute >= trade_to.hour * 60 + trade_to.min
            unlock!
            return true
          end
        end
      end

      unless backtesting?
        if config[:consecutive_losses_allowed] && consecutive_losses >= config[:consecutive_losses_allowed].to_i
          halt_strategy
          reset_consecutive_losses
          reset_consecutive_wins
          unlock!
          return true
        end
      end

      # TODO: This will not play well with strategies that publishes from within step_n functions. Need to handle this some other way.
      # unless backtesting?
      #   # Only run strategy if it hasn't ran in the last few seconds. This could happen when the workers were offline and the queue got really big.
      #   return true if last_ran_at && last_ran_at >= now - 5
      # end

      run_strategy && update_last_ran_at

    # NOTE:
    #
    #   Returning false on a failed network request used to let the step be retried immediately by returning false to rabbitmq in StrategyRun.run_strategy which would trigger a retry.
    #   Since we don't return the true or false to rabbitmq in StrategyRun.run_strategies or StrategyRun.run_strategy anymore, returning false here will not trigger a retry anymore.
    rescue Timeout::Error => e
      unlock!
      raise e
    rescue OandaApiV20::RequestError, Aws::MachineLearning::Errors::ServiceError => e
      message = "Error when executing strategy #{strategy} at step #{step}. #{e}. key_base: #{key_base}"
      message << ", backtest_time: #{backtest_time}" if backtesting?
      data    = { practice: practice, account: account, message: message }
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
      $logger.error "ERROR! strategy_step. #{message}, backtrace: #{e.backtrace}"
      unlock!
      stop_strategy if backtesting? && !BACKTEST_ERRORS_TO_IGNORE.include?(e.class)
      return false
    rescue OandaWorker::Error, StandardError => e
      message = "Error when executing strategy #{strategy} at step #{step}. #{e}. key_base: #{key_base}"
      message << ", backtest_time: #{backtest_time}" if backtesting?
      data    = { practice: practice, account: account, message: message }
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
      $logger.error "ERROR! strategy_step. #{message}, backtrace: #{e.backtrace}"
      unlock!
      stop_strategy if backtesting? && !BACKTEST_ERRORS_TO_IGNORE.include?(e.class)
      return true
    end

    unlock!
    true
  end

  def force_exit_strategy
    begin
      exit_strategy
    rescue Timeout::Error => e
      raise e
    rescue OandaApiV20::RequestError, Aws::MachineLearning::Errors::ServiceError => e
      message = "Error when force exiting strategy #{strategy}. #{e}. key_base: #{key_base}"
      data    = { practice: practice, account: account, message: message }
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
      $logger.error "ERROR! strategy_step. #{message}, backtrace: #{e.backtrace}"
      stop_strategy if backtesting? && !BACKTEST_ERRORS_TO_IGNORE.include?(e.class)
      return false
    rescue OandaWorker::Error, StandardError => e
      message = "Error when force exiting strategy #{strategy}. #{e}. key_base: #{key_base}"
      data    = { practice: practice, account: account, message: message }
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
      $logger.error "ERROR! strategy_step. #{message}, backtrace: #{e.backtrace}"
      stop_strategy if backtesting? && !BACKTEST_ERRORS_TO_IGNORE.include?(e.class)
      return true
    end

    true
  end

  private

  def run_strategy
    message = "RUNNING strategy step_#{step}. key_base: #{key_base}"
    message << ", backtest_time: #{backtest_time.strftime('%Y-%m-%d %H:%M')}" if backtesting?
    publish_backtest_info if backtesting?
    $logger.info message
    options = {
      oanda_client:                 oanda_client,
      oanda_service_client:         oanda_service_client,
      aws_client:                   aws_client,
      status:                       status,
      step:                         step,
      config:                       config,
      max_concurrent_trades:        max_concurrent_trades,
      consecutive_wins:             consecutive_wins,
      consecutive_losses:           consecutive_losses,
      last_transaction_id:          last_transaction_id,
      last_prediction:              last_prediction,
      last_prediction_requested_at: last_prediction_requested_at,
      key_base:                     key_base,
      practice:                     practice,
      account:                      account,
      strategy:                     strategy,
      backtest_index:               backtest_index,
      backtest_time:                backtest_time
    }
    Object.const_get("Strategies::Strategy#{strategy}").new(options).run_step
  end

  def resume_strategy
    $logger.info "FORCE RESUME strategy. key_base: #{key_base}"
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).resume_strategy!
  end

  def exit_strategy
    $logger.info "FORCE EXIT strategy. key_base: #{key_base}"
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).exit_strategy!
  end

  def temporary_exit_strategy
    $logger.info "FORCE TEMPORARY EXIT strategy. key_base: #{key_base}"
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).temporary_exit_strategy!
  end

  def halt_strategy
    $logger.info "FORCE HALT strategy. key_base: #{key_base}"
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).halt_strategy!
  end

  def stop_strategy
    $logger.info "FORCE STOP strategy. key_base: #{key_base}"
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).stop_strategy!
  end

  def update_backtest_progress_bar
    total_candles = StrategyBacktest.total_backtest_candles
    total_candles = 100 if total_candles == 0
    percentage = (backtest_index + 1).to_f / total_candles.to_f * 100
    level = percentage == 100 ? :success : :primary
    data = { practice: practice, account: account, level: level, percentage: percentage.to_i }
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_progress')
  end

  def update_last_ran_at
    $redis.set("#{key_base}:last_ran_at", Time.now.utc)
  end

  def reset_consecutive_wins
    $redis.set("#{key_base}:consecutive_wins", 0)
  end

  def reset_consecutive_losses
    $redis.set("#{key_base}:consecutive_losses", 0)
  end

  def lock!
    $redis.sadd("#{key_base}:step_locks", step)
  end

  def unlock!(steps = [step])
    if steps == :all
      $redis.del("#{key_base}:step_locks")
      return true
    end

    steps = [steps] unless steps.is_a?(Array)

    steps.each do |step|
      $redis.srem("#{key_base}:step_locks", step)
    end

    return true
  end

  def max_concurrent_trades_reached?
    Object.const_get("Strategies::Strategy#{strategy}").new(default_options).max_concurrent_trades_reached?
  end

  def time_between_exit_friday_at_and_market_open_sunday_at?(now, minute, exit_friday_at)
    market_close_friday_at = Time.parse(MARKET_TIMES[:fri][:close_at]).utc
    market_open_sunday_at  = Time.parse(MARKET_TIMES[:sun][:open_at]).utc

    (now.friday? && minute >= exit_friday_at.hour * 60 + exit_friday_at.min) ||
    (now.saturday?) ||
    (now.sunday? && minute < market_open_sunday_at.hour * 60 + market_open_sunday_at.min)
  end

  def time_between_market_close_friday_at_and_market_open_sunday_at?(now, minute)
    market_close_friday_at = Time.parse(MARKET_TIMES[:fri][:close_at]).utc
    market_open_sunday_at  = Time.parse(MARKET_TIMES[:sun][:open_at]).utc

    (now.friday? && minute >= market_close_friday_at.hour * 60 + market_close_friday_at.min) ||
    (now.saturday?) ||
    (now.sunday? && minute < market_open_sunday_at.hour * 60 + market_open_sunday_at.min)
  end

  def publish_backtest_info
    balance = $redis.get('backtest:balance').to_f.round(2)
    spread  = $redis.get('backtest:spread:total').to_f.round(2)
    data    = { practice: practice, account: account, message: "-> balance: $#{balance} spread: $#{spread} [#{backtest_time.strftime('%Y-%m-%d %H:%M')}]", level: :primary, replace: true }
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
  end

  def default_options
    {
      oanda_client:          oanda_client,
      oanda_service_client:  oanda_service_client,
      step:                  step,
      config:                config,
      max_concurrent_trades: max_concurrent_trades,
      last_transaction_id:   last_transaction_id,
      key_base:              key_base,
      practice:              practice,
      account:               account,
      strategy:              strategy,
      backtest_index:        backtest_index,
      backtest_time:         backtest_time
    }
  end
end
