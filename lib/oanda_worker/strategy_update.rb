class StrategyUpdate
  REQUIRED_ATTRIBUTES = [:action, :practice, :account, :strategy, :status].freeze

  attr_accessor :action, :practice, :account, :strategy, :status, :config
  attr_reader   :key_base, :key_status, :key_step, :key_config, :current_status

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end

    @key_base   = "#{practice ? 'practice' : 'live'}:accounts:#{account}:strategies:#{strategy}"
    @key_status = "#{key_base}:status"
    @key_step   = "#{key_base}:step"
    @key_config = "#{key_base}:config"

    # Keys used in strategy base.
    # "#{key_base}:consecutive_wins"
    # "#{key_base}:consecutive_losses"
    # "#{key_base}:last_ran_at"
    # "#{key_base}:last_profit_loss"
    # "#{key_base}:last_prediction"
    # "#{key_base}:last_prediction_requested_at"
    # "#{key_base}:last_transaction_id"

    # Kyes used in specific strategies.
    # "#{key_base}:close_at_entry"

    @data           = { practice: practice, account: account, strategy: strategy }
    @current_status = $redis.get(key_status)
  end

  def update_redis_keys
    begin
      if status_changed?
        case status
        when 'started'
          update_status
          update_config
          set_step_1 unless $redis.exists(key_step)
          start_backtest_server_and_start_queueing if backtesting? && current_status != 'temporary_halted'
        when 'paused'
          update_status
        when 'stopped'
          if backtesting?
            delete_redis_keys
            stop_backtest_server_and_cleanup
          else
            delete_redis_keys if close_all_trades_and_orders
          end
        end

        message = status
      else
        messages = ['config updated']

        if ['started', 'paused', 'halted', 'temporary_halted'].include?(status)
          previous_config = JSON.parse($redis.get(key_config))
          update_config
          config_updates = JSON.parse($redis.get(key_config)).to_a - previous_config.to_a

          config_updates.each do |key, value|
            messages << "#{key} = #{value}"
          end
        end

        message = messages.join(', ')
      end

      data = @data.merge(published_at: Time.now.utc, message: message)
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')

      data = @data.merge(status: status)
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_update')
    rescue Timeout::Error => e
      raise e
    rescue StandardError => e
      false
    end
    true
  end

  private

  def status_changed?
    case status
    when 'started'
      [nil, 'paused', 'halted', 'temporary_halted'].include?(current_status) ? true : false
    when 'paused'
      ['started'].include?(current_status) ? true : false
    when 'stopped'
      ['started', 'paused', 'halted', 'temporary_halted'].include?(current_status) ? true : false
    end
  end

  def update_status
    case status
    when 'started'
      $redis.set(key_status, 'started') unless current_status
      $redis.set(key_status, 'started') if current_status == 'paused'
      $redis.set(key_status, 'started') if current_status == 'halted'
      $redis.set(key_status, 'started') if current_status == 'temporary_halted'
    when 'paused'
      $redis.set(key_status, 'paused') if current_status == 'started'
    end
  end

  def update_config
    $redis.set(key_config, config.to_json)
  end

  def set_step_1
    $redis.set(key_step, 1)
  end

  def delete_redis_keys
    $redis.scan_each(match: "#{key_base}:*") do |key|
      $redis.del(key)
    end
  end

  def close_all_trades_and_orders
    data = { key_base: key_base }
    StrategyStep.new(data).force_exit_strategy
  end

  def start_backtest_server_and_start_queueing
    data = @data.merge(action: 'start_backtest_server_and_start_queueing', config: config)
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_backtest')
  end

  def stop_backtest_server_and_cleanup
    data = @data.merge(action: 'stop_backtest_server_and_cleanup', config: config)
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_backtest')
  end
end
