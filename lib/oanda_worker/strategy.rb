class Strategy
  REQUIRED_ATTRIBUTES = [:oanda_client, :oanda_service_client, :step, :config, :last_transaction_id, :key_base, :practice, :account, :strategy].freeze

  attr_accessor :oanda_client, :oanda_service_client, :aws_client, :backtest_index, :backtest_time,
                :status, :step, :config, :max_concurrent_trades, :consecutive_wins, :consecutive_losses,
                :last_prediction, :last_prediction_requested_at,
                :key_base, :practice, :practice_or_live, :account, :strategy
  attr_reader   :candles_required, :options, :oanda_trade, :oanda_order, :instrument, :pip_size, :round_decimal, :granularity,
                :last_profit_loss, :tag_order, :tag_stop_loss, :tag_take_profit

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end

    @last_transaction_id = options[:last_transaction_id].to_s if options[:last_transaction_id].to_i > 0
    @instrument          = self.class::INSTRUMENT
    @pip_size            = self.class::PIP_SIZE
    @candles_required    = self.class::CANDLES_REQUIRED
    @round_decimal       = pip_size.to_s.split('.').last.size + 1
    @tag_order           = "#{self.class.to_s.downcase.split('::')[1]}_order"
    @tag_stop_loss       = "#{self.class.to_s.downcase.split('::')[1]}_stop_loss"
    @tag_take_profit     = "#{self.class.to_s.downcase.split('::')[1]}_take_profit"
    @step                = step.to_i
    @last_profit_loss    = $redis.get("#{key_base}:last_profit_loss").to_f
    @config              = config.symbolize_keys
    @data                = { practice: practice, account: account, strategy: strategy }
    @granularity         = Definitions::Instrument.candlestick_granularity(config[:chart_interval].to_i)

    if backtesting? && !backtest_time.instance_of?(Time)
      raise OandaWorker::BacktestError, 'The backtest_time attribute is a blank string?' if backtest_time.to_s == '' || backtest_time.to_s == '1970-01-01 00:00:00 UTC'

      begin
        @backtest_time = Time.parse(backtest_time).utc
      rescue ArgumentError, TypeError
        @backtest_time = Time.at(backtest_time.to_i).utc
      end
    end

    oanda_changes
  end

  def run_step
    $logger.info candle_info if backtesting?

    # Function step_n returns true when rule was true and executed, or false when rule was false and not executed.
    if status == 'started'
      self.next_step = step + 1 if self.send("step_#{step}")
    end

    # Return true so StrategyStep can update last_ran_at.
    true
  end

  def resume_strategy!
    self.status = 'started'
    $redis.set("#{key_base}:status", 'started')

    data = @data.merge(status: 'started')
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_update')
    true
  end

  def exit_strategy!
    exit_trades_and_orders!

    self.status = 'stopped'
    $redis.set("#{key_base}:status", 'stopped')

    # This needs to be called so that the profit_loss values can be captured which is only captured with the oanda_changes method.
    oanda_changes
  end

  # Cancel orders and trades. Resume automatically. Used to temporary halt strategy over weekends.
  def temporary_exit_strategy!
    exit_trades_and_orders! && reset_steps

    # This needs to be called so that the profit_loss values can be captured which is only captured with the oanda_changes method.
    oanda_changes

    self.status = 'temporary_halted'
    $redis.set("#{key_base}:status", 'temporary_halted')

    data = @data.merge(status: 'temporary_halted')
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_update')
    true
  end

  # Cancel orders when no trades. Resume automatically. Used when max_concurrent_trades have been reached.
  def temporary_halt_strategy!
    return false if oanda_active_trades.any?
    exit_orders! && reset_steps

    self.status = 'temporary_halted'
    $redis.set("#{key_base}:status", 'temporary_halted')

    data = @data.merge(status: 'temporary_halted')
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_update')
    true
  end

  # Bring strategy to a complete halt when too many consecutive losses reached. Resume manually.
  def halt_strategy!
    self.status = 'halted'
    $redis.set("#{key_base}:status", 'halted')

    data = @data.merge(status: 'halted')
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_update')

    data = @data.merge(published_at: time_now_utc, level: :warning, message: "Trading halted! Too many consecutive losses! #{config[:consecutive_losses_allowed]}")
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
    true
  end

  def stop_strategy!
    data = @data.merge(action: 'update_redis_keys', status: 'stopped')
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_update')
  end

  def max_concurrent_trades_reached?
    @oanda_changes['state']['positions'].size >= max_concurrent_trades
  end

  protected

  def queue_next_run
    $redis.set('backtest:qw_strategy_run_one', true) if backtesting?

    key      = key_base.split(':')[0..3].join(':')
    strategy = key_base.split(':')[4]
    data     = { action: 'run_strategy', key_base: key, strategies: [strategy] }
    data.merge!(backtest_index: backtest_index, backtest_time: backtest_time) if backtesting?

    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_run_one', priority: 10)
    $logger.info "PUBLISHED to qw_strategy_run_one. key_base: #{key}, strategy: #{strategy}, step: #{step}"
    # self.next_step = step + 1 # When the next step is set here, we have to return false at the end of this function to prevent run_step from setting to the next step as well.
    true
  end

  def cleanup
    reset_consecutive_wins
    reset_consecutive_losses
  end

  # TODO: Deprecate! This is now handled inside StrategyStep.run_strategy
  def lock!
    $redis.sadd("#{key_base}:step_locks", step)
  end

  # TODO: Deprecate! This is now handled inside StrategyStep.run_strategy
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

  def close(options = {})
    options[:include_incomplete_candles] ||= true
    @close = nil if options[:refresh]
    @close ||= candles(options)['candles'].last['mid']['c'].to_f.round(round_decimal)
  end

  def close_at_entry
    @close_at_entry ||= $redis.get("#{key_base}:close_at_entry").to_f
  end

  def close_at_entry=(value)
    $redis.set("#{key_base}:close_at_entry", value)
  end

  def candles(options = {})
    if options.delete(:refresh) == true
      refresh_candles = true
    end

    chart_options = {
      oanda_client:   oanda_client,
      instrument:     instrument,
      count:          candles_required || prediction_candles_required || 100,
      chart_interval: config[:chart_interval] || 60
    }.merge!(options)

    if refresh_candles
      @candles = Charts::Candles.new(chart_options).chart
    else
      @candles ||= Charts::Candles.new(chart_options).chart
    end
  end

  def current_candle(options = {})
    @current_candle = nil if options[:refresh]
    @current_candle ||= candles(options)['candles'].last
  end

  def current_candle_full_spread
    (current_candle['ask']['c'].to_f - current_candle['bid']['c'].to_f).abs
  end

  def current_candle_full_spread_in_pips
    (current_candle_full_spread / pip_size).round(round_decimal)
  end

  def acceptable_spread?(max_spread)
    return true if max_spread == 0
    current_candle_full_spread_in_pips <= max_spread.to_f
  end

  def candle_info
    current_candle = candles(include_incomplete_candles: true, refresh: false, price: 'MAB')['candles'].last
    current_candle['mid']
  end

  def oanda_orders(options = {})
    @oanda_orders = nil if options[:refresh]
    @oanda_orders ||= oanda_client.account(account).orders('instrument' => instrument, 'count' => '100', 'state' => 'PENDING').show
  end

  def oanda_active_orders(options = {})
    @oanda_active_orders = nil if options[:refresh]
    @oanda_active_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['MARKET_IF_TOUCHED', 'LIMIT', 'STOP'].include?(order['type']) }.compact
  end

  def oanda_limit_orders(options = {})
    @oanda_limit_orders = nil if options[:refresh]
    @oanda_limit_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['LIMIT'].include?(order['type']) }.compact
  end

  def oanda_stop_orders(options = {})
    @oanda_stop_orders = nil if options[:refresh]
    @oanda_stop_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['STOP'].include?(order['type']) }.compact
  end

  def oanda_stop_loss_orders(options = {})
    @oanda_stop_loss_orders = nil if options[:refresh]
    @oanda_stop_loss_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['STOP_LOSS'].include?(order['type']) }.compact
  end

  def oanda_long_orders(options = {})
    @oanda_long_orders = nil if options[:refresh]
    @oanda_long_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['MARKET_IF_TOUCHED', 'LIMIT', 'STOP'].include?(order['type']) && order['units'].to_i >= 0 }.compact
  end

  def oanda_short_orders(options = {})
    @oanda_short_orders = nil if options[:refresh]
    @oanda_short_orders ||= oanda_orders(options)['orders'].map{ |order| order if ['MARKET_IF_TOUCHED', 'LIMIT', 'STOP'].include?(order['type']) && order['units'].to_i < 0 }.compact
  end

  def oanda_order=(order)
    @oanda_order = order
  end

  def oanda_trades(options = {})
    @oanda_trades = nil if options[:refresh]
    @oanda_trades ||= oanda_client.account(account).trades('instrument' => instrument, 'count' => '100', 'state' => 'OPEN').show
  end

  def oanda_active_trades(options = {})
    @oanda_active_trades = nil if options[:refresh]
    @oanda_active_trades ||= oanda_trades(options)['trades'].map{ |trade| trade if trade['state'] == 'OPEN' }.compact
  end

  def oanda_long_trades(options = {})
    @oanda_long_trades = nil if options[:refresh]
    @oanda_long_trades ||= oanda_trades(options)['trades'].map{ |trade| trade if trade['state'] == 'OPEN' && trade['initialUnits'].to_f >= 0 }.compact
  end

  def oanda_short_trades(options = {})
    @oanda_short_trades = nil if options[:refresh]
    @oanda_short_trades ||= oanda_trades(options)['trades'].map{ |trade| trade if trade['state'] == 'OPEN' && trade['initialUnits'].to_f < 0 }.compact
  end

  def oanda_last_trade(options = {})
    @oanda_last_trade = nil if options[:refresh]
    @oanda_last_trade = oanda_trades(options)['trades'].last ? { 'trade' => oanda_trades['trades'].last, 'lastTransactionID' => oanda_trades['lastTransactionID'] } : nil
  end

  def oanda_trade=(trade)
    @oanda_trade = trade.keys.include?('trade') ? trade : { 'trade' => trade, 'lastTransactionID' => last_transaction_id }
  end

  def oanda_changes(options = {})
    @oanda_changes = nil if options[:refresh]
    return @oanda_changes if @oanda_changes && @oanda_changes['lastTransactionID'].to_s == last_transaction_id.to_s

    # http://developer.oanda.com/rest-live-v20/troubleshooting-errors/
    begin
      @oanda_changes = oanda_client.account(account).changes('sinceTransactionID' => last_transaction_id).show
    rescue OandaApiV20::RequestError => e
      exception = Http::ExceptionsParser.new(e)
      raise e unless exception.response.code == 416
      raise e unless JSON.parse(exception.response.body)['errorCode'] == 'INVALID_RANGE'

      caught_last_transaction_id = JSON.parse(exception.response.body)['lastTransactionID']
      @oanda_changes = oanda_client.account(account).changes('sinceTransactionID' => caught_last_transaction_id).show

      raise e unless @oanda_changes
    end

    # @oanda_changes['changes']['tradesOpened'].each do |trade|
    #   next unless trade['instrument'] == instrument
    #   next unless trade['state'] == 'OPEN'
    #   self.oanda_trade = trade
    #   $logger.info "OPENED! trade. key_base: #{key_base}, oanda_trade: #{oanda_trade}"
    #   data = @data.merge({
    #     published_at:   time_now_utc,
    #     level:          :info,
    #     message:        "#{oanda_trade['trade']['initialUnits'].gsub('-', '')} units #{oanda_trade_type} @ #{oanda_trade['trade']['price']} opened (#{oanda_trade['trade']['id']})",
    #     position:       oanda_trade_type,
    #     action:         :opened,
    #     units:          oanda_trade['trade']['initialUnits'].gsub('-', ''),
    #     price:          oanda_trade['trade']['price'],
    #     transaction_id: oanda_trade['trade']['id']
    #   })
    #   $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
    # end

    @oanda_changes['changes']['transactions'].each do |transaction|
      next unless transaction['instrument'] == instrument

      if transaction['reason'] == 'INSUFFICIENT_MARGIN'
        $logger.info "INSUFFICIENT_MARGIN! key_base: #{key_base}, transaction: #{transaction}"
        data = @data.merge({
          published_at:   time_now_utc,
          level:          :warning,
          message:        "INSUFFICIENT_MARGIN for order #{transaction['orderID']}",
          transaction_id: transaction['id']
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      end

      if transaction['reason'] == 'MARGIN_CLOSEOUT'
        # FIXME: Keeps on looping over here when triggered in backtesting mode and only stops when a new order or trade gets triggered?
        # The line below was added to keep this from happening.
        next if @oanda_changes['changes']['tradesClosed'].empty?

        $logger.info "MARGIN_CLOSEOUT! key_base: #{key_base}, transaction: #{transaction}"
        data = @data.merge({
          published_at:   time_now_utc,
          level:          :warning,
          message:        'MARGIN_CLOSEOUT',
          transaction_id: transaction['id']
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')

        # halt_strategy!
      end

      if transaction['type'] == 'ORDER_FILL'
        if transaction['tradeOpened']
          trade      = transaction['tradeOpened']
          trade_type = trade['units'].to_i >= 0 ? :long : :short
          units      = trade['units'].to_i

          $logger.info "OPENED! trade. key_base: #{key_base}, trade: #{trade}"

          data = @data.merge(
            published_at:   time_now_utc,
            level:          :info,
            message:        "#{units.to_s.gsub('-', '')} units #{trade_type} @ #{trade['price']} opened (#{trade['tradeID']})",
            position:       trade_type,
            action:         :opened,
            units:          units.to_s.gsub('-', ''),
            price:          trade['price'],
            transaction_id: transaction['id']
          )

          $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        end

        if transaction['tradeReduced']
          trade          = transaction['tradeReduced']
          activity_level = trade['realizedPL'].to_f >= 0 ? :success : :danger
          trade_type     = trade['units'].to_i >= 0 ? :short : :long
          units          = trade['units'].to_i
          profit_loss    = trade['realizedPL'].to_f

          $logger.info "REDUCED! trade. key_base: #{key_base}, trade: #{trade}"

          data = @data.merge(
            published_at:   time_now_utc,
            level:          activity_level,
            message:        "#{units.to_s.gsub('-', '')} units #{trade_type} @ #{trade['price']} reduced (#{trade['tradeID']}) #{'%.02f' % profit_loss}",
            position:       trade_type,
            action:         :reduced,
            units:          units,
            price:          trade['price'],
            transaction_id: trade['tradeID'],
            profit_loss:    profit_loss
          )

          $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        end

        if transaction['tradesClosed']
          transaction['tradesClosed'].each do |trade|
            activity_level = trade['realizedPL'].to_f >= 0 ? :success : :danger
            trade_type     = trade['units'].to_i >= 0 ? :short : :long
            units          = trade['units'].to_i
            profit_loss    = trade['realizedPL'].to_f

            $logger.info "CLOSED! trade. key_base: #{key_base}, trade: #{trade}"

            data = @data.merge(
              published_at:   time_now_utc,
              level:          activity_level,
              message:        "#{units.to_s.gsub('-', '')} units #{trade_type} @ #{trade['price']} closed (#{trade['tradeID']}) #{'%.02f' % profit_loss}",
              position:       trade_type,
              action:         :closed,
              units:          units,
              price:          trade['price'],
              transaction_id: trade['tradeID'],
              profit_loss:    profit_loss
            )

            $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
            delete_last_prediction
          end
        end
      end
    end

    # Temporary halt the strategy when max_concurrent_trades have been reached and the active trade's instrument is not of this strategy.
    # Resume the strategy when the max_concurrent_trades is back to normal.
    if status && status != 'stopped'
      if max_concurrent_trades_reached?
        if status == 'started'
          temporary_halt_strategy! unless oanda_active_trades.any?
        end
      else
        if status == 'temporary_halted'
          resume_strategy!
        end
      end
    end

    # Duplicate logs! We already log this with exit_order! which includes the position and units arguments to be logged in the DB.
    # @oanda_changes['changes']['ordersCancelled'].each do |order|
    #   next unless order['instrument'] == instrument
    #   next unless order['state'] == 'CANCELLED'
    #   self.oanda_order = order
    #   $logger.info "CANCELLED! order. key_base: #{key_base}, oanda_order: #{oanda_order}"
    #   data = @data.merge({
    #     published_at:   time_now_utc,
    #     level:          :secondary,
    #     message:        "order #{oanda_order['id']} cancelled (#{oanda_order['cancellingTransactionID']})",
    #     action:         :cancelled,
    #     price:          oanda_order['price'],
    #     transaction_id: oanda_order['id']
    #   })
    #   $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
    # end

    # TODO: Catch the following as well and notify accordingly:
    #
    #   @oanda_changes['changes']['ordersCreated']
    #   @oanda_changes['changes']['ordersCancelled']
    #   @oanda_changes['changes']['ordersFilled']
    #   @oanda_changes['changes']['ordersTriggered']
    #   @oanda_changes['changes']['tradesClosed'] # This is handled throught @oanda_changes['changes']['transactions']
    #   @oanda_changes['changes']['tradesReduced'] # This is handled throught @oanda_changes['changes']['transactions']

    self.last_transaction_id = @oanda_changes['lastTransactionID']
    @oanda_changes
  end

  def last_transaction_id
    @last_transaction_id ||= $redis.get("#{key_base}:last_transaction_id")
  end

  def last_transaction_id=(id)
    return unless id.to_i > 0
    $redis.set("#{key_base}:last_transaction_id", id)
    @last_transaction_id = id.to_s
  end

  # TODO: Search and replace create_long_order! with create_order_at!(:long, prices).
  def create_long_order!(prices = {})
    create_order_at!(:long, prices)
  end

  # TODO: Search and replace create_short_order! with create_order_at!(:short, prices).
  def create_short_order!(prices = {})
    create_order_at!(:short, prices)
  end

  def create_order!(type)
    create_or_update_order!(:create, type)
  end

  # TODO: Search and replace update_long_order! with create_order_at!(:long, prices).
  def update_long_order!(id, prices = {})
    update_order_at!(:long, id, prices)
  end

  # TODO: Search and replace update_short_order! with create_order_at!(:short, prices).
  def update_short_order!(id, prices = {})
    update_order_at!(:short, id, prices)
  end

  def update_order!(id, type)
    create_or_update_order!(:update, type, id)
  end

  def create_or_update_order!(create_or_update, type, id = nil)
    case create_or_update
    when :create
      self.oanda_order = oanda_client.account(account).order(options).create
    when :update
      self.oanda_order = oanda_client.account(account).order(id, options).update
    end

    type = type.to_sym

    return false unless oanda_order
    # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.

    case create_or_update
    when :create
      $logger.info "CREATE! strategy. key_base: #{key_base}, oanda_order: #{oanda_order}"
    when :update
      $logger.info "UPDATE! strategy. key_base: #{key_base}, oanda_order: #{oanda_order}"
    end

    # orderCancelTransaction available on create and update.
    if oanda_order['orderCancelTransaction']
      message = "#{oanda_order['orderCancelTransaction']['reason']}"
      message << " by order #{oanda_order['orderCancelTransaction']['replacedByOrderID']}" if oanda_order['orderCancelTransaction']['replacedByOrderID']
      message << " on #{type} (#{oanda_order['orderCancelTransaction']['orderID']})"
      data = @data.merge(published_at: time_now_utc, level: :warning, message: message, transaction_id: oanda_order['orderCancelTransaction']['id'])
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      return false if create_or_update == :create
    end

    # replacingOrderCancelTransaction available only on update.
    if oanda_order['replacingOrderCancelTransaction']
      message = "#{oanda_order['replacingOrderCancelTransaction']['reason']} on #{type} (#{oanda_order['replacingOrderCancelTransaction']['orderID']})"
      data = @data.merge(published_at: time_now_utc, level: :warning, message: message, transaction_id: oanda_order['replacingOrderCancelTransaction']['id'])
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      return false if create_or_update == :update
    end

    if oanda_order['orderFillTransaction']
      if oanda_order['orderFillTransaction']['tradeReduced'] || oanda_order['orderFillTransaction']['tradesClosed']
        message = "order #{oanda_order['orderFillTransaction']['id']} immediately filled when created! "
        message << "closed trade #{oanda_order['orderFillTransaction']['tradesClosed'].map{ |trade| trade['tradeID'] }.join(', ')}" if oanda_order['orderFillTransaction']['tradesClosed']
        message << "reduced trade #{oanda_order['orderFillTransaction']['tradeReduced']['tradeID']}" if oanda_order['orderFillTransaction']['tradeReduced']
        data = @data.merge(published_at: time_now_utc, level: :warning, message: message, transaction_id: oanda_order['orderFillTransaction']['id'])
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        return false if oanda_order['orderFillTransaction']['tradeReduced']
      end

      if oanda_order['orderFillTransaction']['tradeOpened']
        data = @data.merge({
          published_at:   time_now_utc,
          level:          :info,
          message:        "#{oanda_order['orderFillTransaction']['tradeOpened']['units'].gsub('-', '')} units #{type} @ #{oanda_order['orderFillTransaction']['price']} opened (#{oanda_order['orderFillTransaction']['id']})",
          position:       type,
          action:         :opened,
          units:          oanda_order['orderFillTransaction']['tradeOpened']['units'].gsub('-', ''),
          price:          oanda_order['orderFillTransaction']['price'],
          transaction_id: oanda_order['orderFillTransaction']['id']
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        return true
      end
    end

    if oanda_order['orderCreateTransaction']
      message = "#{oanda_order['orderCreateTransaction']['units'].gsub('-', '')} units #{type} @ #{oanda_order['orderCreateTransaction']['price']} created (#{oanda_order['orderCreateTransaction']['id']})"
      message << " sl: #{oanda_order['orderCreateTransaction']['stopLossOnFill']['price']}" if oanda_order['orderCreateTransaction']['stopLossOnFill']
      message << " tp: #{oanda_order['orderCreateTransaction']['takeProfitOnFill']['price']}" if oanda_order['orderCreateTransaction']['takeProfitOnFill']
      data = @data.merge({
        published_at:   time_now_utc,
        level:          :secondary,
        message:        message,
        position:       type,
        action:         :created,
        units:          oanda_order['orderCreateTransaction']['units'].gsub('-', ''),
        price:          oanda_order['orderCreateTransaction']['price'],
        take_profit:    oanda_order['orderCreateTransaction']['takeProfitOnFill'] ? oanda_order['orderCreateTransaction']['takeProfitOnFill']['price'] : nil,
        stop_loss:      oanda_order['orderCreateTransaction']['stopLossOnFill'] ? oanda_order['orderCreateTransaction']['stopLossOnFill']['price'] : nil,
        transaction_id: oanda_order['orderCreateTransaction']['id']
      })
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      return true
    end

    false
  end

  def create_order_at!(type, prices = {})
    create_or_update_order_at!(:create, type, prices)
  end

  def update_order_at!(type, id, prices = {})
    create_or_update_order_at!(:update, type, prices, id)
  end

  def create_or_update_order_at!(create_or_update, type, prices = {}, id = nil)
    order_price       = prices[:order_price]
    take_profit_price = prices[:take_profit_price]
    stop_loss_price   = prices[:stop_loss_price]
    take_profit_pips  = prices[:take_profit_pips]
    stop_loss_pips    = prices[:stop_loss_pips]
    units             = prices[:units]
    tag               = prices[:tag]

    type = type.to_sym

    options

    if take_profit_pips || take_profit_price
      take_profit_price ||= order_price + take_profit_pips.to_f * pip_size

      @options['order']['takeProfitOnFill'] = {
        'timeInForce' => 'GTC',
        'price' => take_profit_price.round(round_decimal).to_s
      }
    end

    if stop_loss_pips || stop_loss_price
      stop_loss_price ||= order_price + stop_loss_pips.to_f * pip_size
      stop_loss_pips  ||= -((order_price - stop_loss_price).abs / pip_size).ceil

      @options['order']['stopLossOnFill'] = {
        'timeInForce' => 'GTC',
        'price' => stop_loss_price.round(round_decimal).to_s
      }
    end

    @options['order']['price'] = order_price.round(round_decimal).to_s unless ['MARKET', 'TRAILING_STOP_LOSS'].include?(options['order']['type'])
    @options['order']['units'] = (units || calculated_units_from_balance(config[:margin], type, stop_loss_pips) || config[:units]).to_s

    if @options['order']['units'] == '0'
      message = "Not enough available balance to place an order with at least 1 unit. strategy: #{strategy}, step #{step}, key_base: #{key_base}"
      data    = { practice: practice, account: account, message: message, level: 'warning' }
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
      $logger.warn "WARNING! #{message}"
      stop_strategy! if backtesting?
      return false
    end

    @options['order']['units'] = "-#{@options['order']['units']}" if type == :short
    @options['order']['clientExtensions']['tag'] = tag if tag

    case create_or_update
    when :create
      return create_order!(type)
    when :update
      return update_order!(id, type)
    end

    false
  end

  def create_order_at_offset!(type, prices = {})
    create_or_update_order_at_offset!(:create, type, prices)
  end

  def update_order_at_offset!(type, id, prices = {})
    create_or_update_order_at_offset!(:update, type, prices, id)
  end

  # Uses close_at_entry to determine the order_price.
  def create_or_update_order_at_offset!(create_or_update, type, prices = {}, id = nil)
    close                = prices[:close] || close_at_entry
    order_pips           = prices[:order_pips]
    order_price          = close + order_pips.to_f * pip_size
    prices[:order_price] = order_price
    create_or_update_order_at!(create_or_update, type, prices, id)
  end

  # NOTE: Uses last trade if oanda_trade not explicitly set before.
  def exit_trade!(trade = nil)
    self.oanda_trade = trade if trade
    self.oanda_trade = oanda_last_trade unless oanda_trade
    return false unless oanda_trade

    self.oanda_order         = oanda_client.account(account).trade(oanda_trade['trade']['id']).close
    # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.
    $logger.info "CLOSED! trade. key_base: #{key_base}, oanda_order: #{oanda_order}"
    return false unless oanda_order

    if oanda_order['orderCancelTransaction']
      data = @data.merge(published_at: time_now_utc, level: :warning, message: "#{oanda_order['orderCancelTransaction']['reason']} on #{oanda_trade_type} (#{oanda_order['orderCancelTransaction']['orderID']})", transaction_id: oanda_order['orderCancelTransaction']['id'])
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      return false
    end

    if oanda_order['orderFillTransaction']
      profit_loss           = order_profit_loss
      self.last_profit_loss = profit_loss
      data = @data.merge({
        published_at:   time_now_utc,
        level:          :secondary,
        message:        "#{oanda_order['orderFillTransaction']['units'].gsub('-', '')} units #{oanda_order_type} @ #{oanda_order['orderFillTransaction']['price']} closed (#{oanda_order['orderFillTransaction']['id']}) #{'%.02f' % profit_loss}",
        position:       oanda_order_type,
        action:         :closed,
        units:          oanda_order['orderFillTransaction']['units'].gsub('-', ''),
        price:          oanda_order['orderFillTransaction']['price'],
        transaction_id: oanda_order['orderFillTransaction']['id'],
        profit_loss:    nil # NOTE: Only oanda_changes may update profit_loss. Updating anywhere else will accumulate double profits or losses on the charts.
      })
      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
      delete_last_prediction
      return true
    end

    false
  end

  def exit_order!(order)
    self.oanda_order = oanda_client.account(account).order(order['id']).cancel
    # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.
    $logger.info "CANCELLED! order. key_base: #{key_base}, order: #{order}, oanda_order: #{oanda_order}"

    if oanda_order['orderCancelTransaction']
      data = @data.merge({
        published_at:   time_now_utc,
        level:          :secondary,
        message:        "order #{oanda_order['orderCancelTransaction']['orderID']} cancelled (#{oanda_order['orderCancelTransaction']['id']})",
        action:         :cancelled,
        price:          order['price'],
        transaction_id: order['id']
      })

      if order['units']
        type = order['units'].to_i >= 0 ? 'long' : 'short'
        data.merge!(position: type, units: order['units'].gsub('-', ''))
      end

      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
    end

    true
  end

  def exit_orders!(type = :all)
    orders = 
      case type.to_sym
      when :all
        oanda_orders['orders']
      when :long
        oanda_long_orders
      when :short
        oanda_short_orders
      end

    orders.each do |order|
      next unless ['MARKET_IF_TOUCHED', 'LIMIT', 'STOP'].include?(order['type'])
      exit_order!(order)
    end

    true
  end

  def exit_position!
    begin
      oanda_position = oanda_client.account(account).position(instrument).show
    rescue OandaApiV20::RequestError => e
      exception = Http::ExceptionsParser.new(e)
      raise e unless exception.response.code == 404
      raise e unless JSON.parse(exception.response.body)['errorCode'] == 'NO_SUCH_POSITION'
      return false
    end

    return false unless oanda_position

    if oanda_position['position']['long']['units'].to_i > 0
      self.oanda_order = oanda_client.account(account).position(instrument, 'longUnits' => 'ALL').close
      # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.

      if oanda_order['longOrderCancelTransaction'] && !oanda_order['longOrderCancelTransaction'].empty?
        data = @data.merge(published_at: time_now_utc, level: :warning, message: "#{oanda_order['longOrderCancelTransaction']['reason']} on #{oanda_order_type} (#{oanda_order['longOrderCancelTransaction']['orderID']})", transaction_id: oanda_order['longOrderCancelTransaction']['id'])
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        return false
      end

      if oanda_order['longOrderFillTransaction'] && !oanda_order['longOrderFillTransaction'].empty?
        profit_loss = order_profit_loss
        data = @data.merge({
          published_at:   time_now_utc,
          level:          :secondary,
          message:        "#{oanda_order['longOrderFillTransaction']['units'].gsub('-', '')} units long @ #{oanda_order['longOrderFillTransaction']['price']} closed (#{oanda_order['longOrderFillTransaction']['id']}) #{'%.02f' % profit_loss}",
          position:       :long,
          action:         :closed,
          units:          oanda_order['longOrderFillTransaction']['units'].gsub('-', ''),
          price:          oanda_order['longOrderFillTransaction']['price'],
          transaction_id: oanda_order['longOrderFillTransaction']['id'],
          profit_loss:    nil # NOTE: Only oanda_changes may update profit_loss. Updating anywhere else will accumulate double profits or losses on the charts.
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        $logger.info "CLOSED! position. key_base: #{key_base}, oanda_order: #{oanda_order}"
        oanda_changes(refresh: true) && backtest_export
        return true
      end
    end

    if oanda_position['position']['short']['units'].to_i < 0
      self.oanda_order = oanda_client.account(account).position(instrument, 'shortUnits' => 'ALL').close
      # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.

      if oanda_order['shortOrderCancelTransaction'] && !oanda_order['shortOrderCancelTransaction'].empty?
        data = @data.merge(published_at: time_now_utc, level: :warning, message: "#{oanda_order['shortOrderCancelTransaction']['reason']} on #{oanda_order_type} (#{oanda_order['shortOrderCancelTransaction']['orderID']})", transaction_id: oanda_order['shortOrderCancelTransaction']['id'])
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        return false
      end

      if oanda_order['shortOrderFillTransaction'] && !oanda_order['shortOrderFillTransaction'].empty?
        profit_loss = order_profit_loss
        data = @data.merge({
          published_at:   time_now_utc,
          level:          :secondary,
          message:        "#{oanda_order['shortOrderFillTransaction']['units'].gsub('-', '')} units short @ #{oanda_order['shortOrderFillTransaction']['price']} closed (#{oanda_order['shortOrderFillTransaction']['id']}) #{'%.02f' % profit_loss}",
          position:       :short,
          action:         :closed,
          units:          oanda_order['shortOrderFillTransaction']['units'].gsub('-', ''),
          price:          oanda_order['shortOrderFillTransaction']['price'],
          transaction_id: oanda_order['shortOrderFillTransaction']['id'],
          profit_loss:    nil # NOTE: Only oanda_changes may update profit_loss. Updating anywhere else will accumulate double profits or losses on the charts.
        })
        $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
        $logger.info "CLOSED! position. key_base: #{key_base}, oanda_order: #{oanda_order}"
        oanda_changes(refresh: true) && backtest_export
        return true
      end
    end

    false
  end

  def exit_trades_and_orders!
    $logger.info "EXIT! strategy. key_base: #{key_base}"
    exit_position!
    exit_orders!
    true
  end

  def close_orders_when_trades_empty!
    oanda_active_trades.empty? && exit_trades_and_orders!
  end

  def update_trade!(attributes)
    options = {}
    options.merge!('takeProfit' => { 'timeInForce' => 'GTC', 'price' => attributes[:take_profit].to_s }) if attributes[:take_profit]
    options.merge!('stopLoss' => { 'timeInForce' => 'GTC', 'price' => attributes[:stop_loss].to_s }) if attributes[:stop_loss]
    options.merge!('trailingStopLoss' => { 'timeInForce' => 'GTC', 'price' => attributes[:trailing_stop_loss].to_s }) if attributes[:trailing_stop_loss]
    self.oanda_order = oanda_client.account(account).trade(attributes[:id], options).update
    # self.last_transaction_id = oanda_order['lastTransactionID'] # NOTE: Transactions should be published with the oanda_changes call.
    $logger.info "UPDATE_TRADE! strategy. key_base: #{key_base}, oanda_order: #{oanda_order}"

    message = "#{attributes[:id]} "
    message << "tp @ #{attributes[:take_profit]} " if attributes[:take_profit]
    message << "sl @ #{attributes[:stop_loss]} " if attributes[:stop_loss]
    message << "ts @ #{attributes[:trailing_stop_loss]} " if attributes[:trailing_stop_loss]
    message << "(#{oanda_order['lastTransactionID']})"
    data = @data.merge(published_at: time_now_utc, level: :secondary, message: message, transaction_id: oanda_order['lastTransactionID'])
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
  end

  # TODO: Deprecate!
  def take_profit!(type, pips)
    price = oanda_order['orderFillTransaction']['price'].to_f

    case type
    when :long
      price = price + pips
    when :short
      price = price - pips
    end

    options = {
      'order' => {
        'type'        => 'TAKE_PROFIT',
        'timeInForce' => 'GTC',
        'tradeID'     => oanda_order['orderFillTransaction']['id'],
        'price'       => price.to_s
      }
    }

    self.oanda_order         = oanda_client.account(account).order(options).create
    # self.last_transaction_id = oanda_order['lastTransactionID']
    $logger.info "TAKE_PROFIT! strategy. key_base: #{key_base}, oanda_order: #{oanda_order}"
  end

  # TODO: Deprecate!
  def stop_loss!(type, pips)
    price = oanda_order['orderFillTransaction']['price'].to_f

    case type
    when :long
      price = price - pips
    when :short
      price = price + pips
    end

    options = {
      'order' => {
        'type'        => 'STOP_LOSS',
        'timeInForce' => 'GTC',
        'tradeID'     => oanda_order['orderFillTransaction']['id'],
        'price'       => price.to_s
      }
    }

    self.oanda_order         = oanda_client.account(account).order(options).create
    # self.last_transaction_id = oanda_order['lastTransactionID']
    $logger.info "STOP_LOSS! strategy. key_base: #{key_base}, oanda_order: #{oanda_order}"
  end

  def redis_step=(step)
    step = step.to_i
    raise OandaWorker::ZeroNotAllowed, "Can't work with a 0 when resetting steps" if step == 0
    $redis.set("#{key_base}:step", step)
  end

  # Returns integer.
  def next_step=(value)
    value = value.to_i
    raise OandaWorker::ZeroNotAllowed, "Can't work with a 0 when setting next step" if value == 0
    self.redis_step = self.respond_to?("step_#{value}") ? value : 1
  end

  # Returns boolean.
  def step_to(value)
    value = value.to_i
    (self.next_step = value) == value
  end

  def reset_steps
    cleanup
    unlock!(:all)
    self.next_step = 1
  end

  # Override this method for each strategy as needed.
  #
  # This method requires stop_loss_pips to be supplied when trading with a percentage of the balance.
  #
  # https://www.oanda.com/forex-trading/analysis/currency-units-calculator
  #
  # TODO: The margin or balance percentage is currently only working for the Forex, Commodities and Metals with a base currency. So EUR in the example of EUR_JPY.
  #
  #   EUR_JPY:
  #
  #   Base Currency: EUR
  #   Home Currency: USD
  #
  # FIXME: Indices and Bonds without a _USD counterpart does not calculate units correctly as per the iOS app.
  #        There are also other pairs like XAG_AUD that also doesn't calculate correctly, the iOS app would calculate 1039 available units where the calculator would calculate 5235 units.
  def calculated_units_from_balance(margin = nil, type = nil, stop_loss_pips = nil)
    return nil unless margin
    type = type.to_sym
    stop_loss_pips = max_stop_loss_pips unless stop_loss_pips
    raise ArgumentError, 'stop_loss_pips can not be 0' if stop_loss_pips == 0

    oanda_account = oanda_client.account(account).summary.show

    margin                      = margin.to_f
    balance                     = oanda_account['account']['balance'].to_f
    home_currency               = oanda_account['account']['currency']
    leverage                    = oanda_account['account']['marginRate'].to_f # 0.01 = 100:1, 0.02 = 50:1, 1 = 1:1
    instrument_counter_currency = instrument.split('_')[1]
    trigger_price               = TRIGGER_CONDITION['DEFAULT'] # TODO: Use order's trigger condition.

    unless instrument.include?(home_currency)
      conversion_pair             = conversion_pair_for(instrument, home_currency)
      conversion_base_currency    = conversion_pair.split('_')[0]
      conversion_counter_currency = conversion_pair.split('_')[1]
    end

    begin
      instrument_candles      = oanda_client.instrument(instrument).candles(include_incomplete_candles: true, count: 1, price: 'MAB', granularity: 'S5').show
      conversion_pair_candles = oanda_client.instrument(conversion_pair).candles(include_incomplete_candles: true, count: 1, price: 'M', granularity: 'S5').show if conversion_pair
    rescue OandaApiV20::RequestError => e
      exception = Http::ExceptionsParser.new(e)
      raise e unless exception.response.code == 504
      raise e unless JSON.parse(exception.response.body)['errorMessage'] == 'Timeout waiting for response.'
      raise OandaWorker::StrategyError, "Trying to request candles for a possible invalid conversion_pair #{conversion_pair}. Original exception: #{e}" if conversion_pair
      raise OandaWorker::StrategyError, "Trying to request candles for a possible invalid instrument #{instrument}. Original exception: #{e}" if instrument
    end

    current_candle                = instrument_candles['candles'].last
    instrument_exchange_rate      = instrument_candles['candles'].last['mid']['c'].to_f
    conversion_pair_exchange_rate = conversion_pair_candles['candles'].last['mid']['c'].to_f if conversion_pair
    spread                        = instrument_candles['candles'].last['ask']['c'].to_f - instrument_candles['candles'].last['bid']['c'].to_f

    if conversion_pair
      if conversion_counter_currency == home_currency
        pip_price = conversion_pair_exchange_rate / instrument_exchange_rate * pip_size
      else
        pip_price = (1 / conversion_pair_exchange_rate) / instrument_exchange_rate * pip_size
      end
    else
      if instrument_counter_currency == home_currency
        pip_price = pip_size
      else
        pip_price = (1 / instrument_exchange_rate) * pip_size
      end
    end

    raise OandaWorker::StrategyError, "Could not calculate pip_price for #{instrument}" unless pip_price

    # spread      = (instrument_candles['candles'].last['ask']['c'].to_f - instrument_candles['candles'].last['bid']['c'].to_f) / pip_size
    # risk_amount = (balance * margin / 100 - spread).floor
    # risk_pips   = stop_loss_pips.abs
    # units       = (risk_amount.to_f / risk_pips.to_f / pip_price).round(round_decimal)

    available_units = balance / (current_candle[trigger_price[type]]['c'].to_f + spread) / leverage
    units           = available_units * margin / 100

    units.floor
  end

  def conversion_pair_for(instrument, home_currency)
    return instrument if instrument.include?(home_currency)

    conversion_pair = nil
    base_currency   = instrument.split('_')[0]

    INSTRUMENTS.keys.each do |instrument|
      if instrument.include?(home_currency) && instrument.include?(base_currency)
        conversion_pair = instrument
        break
      end
    end

    raise OandaWorker::StrategyError, "Could not find conversion_pair for #{instrument}" unless conversion_pair
    conversion_pair
  end

  # Mimic margin stop out at a 100:1 leverage.
  # TODO: Not tested yet! Needs to be revised.
  def max_stop_loss_pips
    # oanda_account              = oanda_client.account(account).summary.show
    # leverage                   = oanda_account['account']['marginRate'].to_f # 0.01 = 100:1, 0.02 = 50:1, 1 = 1:1
    leverage                   = 0.01
    leverage_percentage        = 100 / (leverage * 100)
    margin_stop_out_percentage = 50
    (leverage_percentage / config[:margin] * margin_stop_out_percentage).floor
  end

  def prediction
    @prediction ||= begin
      raise OandaWorker::PredictionError, 'No candles initialized to send for a prediction.' unless candles
      # granularity = Definitions::Instrument.candlestick_granularity(config[:chart_interval].to_i) # Now initialized in constructor. (2018-11-28)

      instrument_prediction = 
        case instrument
        when 'NATGAS_USD'
          Object.const_get("Predictions::NATGASUSD#{granularity}").new(aws_client: aws_client, candles: candles).prediction
        when 'SUGAR_USD'
          Object.const_get("Predictions::SUGARUSD#{granularity}").new(aws_client: aws_client, candles: candles).prediction
        when 'WTICO_USD'
          Object.const_get("Predictions::WTICOUSD#{granularity}").new(aws_client: aws_client, candles: candles).prediction
        end

      raise OandaWorker::PredictionError, 'No prediction returned. Probably no prediction model for instrument.' unless instrument_prediction
      set_last_prediction_and_requested_at(instrument_prediction)
      instrument_prediction
    end
  end

  def prediction_interval_on_entry
    last_profit_loss >= 0 ? prediction_interval_on_won : prediction_interval_on_lost
  end

  def increment_consecutive_wins
    $redis.incr("#{key_base}:consecutive_wins")
  end

  def increment_consecutive_losses
    $redis.incr("#{key_base}:consecutive_losses")
  end

  def reset_consecutive_wins
    $redis.set("#{key_base}:consecutive_wins", 0)
  end

  def reset_consecutive_losses
    $redis.set("#{key_base}:consecutive_losses", 0)
  end

  def set_last_prediction_and_requested_at(prediction)
    raise OandaWorker::PredictionError, 'No current prediction to save.' unless prediction
    @last_prediction              = prediction
    @last_prediction_requested_at = time_now_utc
    $redis.set("#{key_base}:last_prediction", prediction)
    $redis.set("#{key_base}:last_prediction_requested_at", time_now_utc)
  end

  def delete_last_prediction
    @last_prediction = nil
    $redis.del("#{key_base}:last_prediction")
  end

  def publish_prediction_values
    raise OandaWorker::PredictionError, 'No current prediction to publish.' unless prediction
    message = "prediction: #{prediction.round(round_decimal)}"
    message << "; last_prediction: #{last_prediction.round(round_decimal)}" if last_prediction
    message << "; close: #{candles['candles'][-1]['mid']['c'].to_f}"
    data = @data.merge(published_at: time_now_utc, message: message)
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
  end

  def last_profit_loss=(profit_loss)
    @last_profit_loss = profit_loss.to_f
    $redis.set("#{key_base}:last_profit_loss", profit_loss.to_f)
    last_profit_loss < 0 ? increment_consecutive_losses && reset_consecutive_wins : increment_consecutive_wins && reset_consecutive_losses
  end

  def order_profit_loss
    return oanda_order['orderFillTransaction']['pl'].to_f + oanda_order['orderFillTransaction']['financing'].to_f if oanda_order['orderFillTransaction']
    return oanda_order['longOrderFillTransaction']['pl'].to_f + oanda_order['longOrderFillTransaction']['financing'].to_f if oanda_order['longOrderFillTransaction']
    return oanda_order['shortOrderFillTransaction']['pl'].to_f + oanda_order['shortOrderFillTransaction']['financing'].to_f if oanda_order['shortOrderFillTransaction']
  end

  def oanda_order_type
    oanda_order['orderFillTransaction']['units'].to_f >= 0 ? 'long' : 'short' if oanda_order['orderFillTransaction']
    oanda_order['longOrderFillTransaction']['units'].to_f >= 0 ? 'long' : 'short' if oanda_order['longOrderFillTransaction']
    oanda_order['shortOrderFillTransaction']['units'].to_f >= 0 ? 'long' : 'short' if oanda_order['shortOrderFillTransaction']
  end

  # NOTE: Uses last trade if oanda_trade not explicitly set before.
  def oanda_trade_type
    trade = oanda_trade ? oanda_trade : oanda_last_trade
    trade['trade']['initialUnits'].to_f >= 0 ? 'long' : 'short'
  end

  def order_closed_because_of_insufficient_margin?
    result = false

    oanda_changes['changes']['transactions'].map do |transaction|
      if transaction['type'] == 'ORDER_CANCEL' && transaction['reason'] == 'INSUFFICIENT_MARGIN'
        result = true
        break
      end
    end

    result
  end

  # Builds a multi dimensional array from the price records returned from the OandaService API.
  # This is used to determine where double top and bottom breakouts will occur so we can place our orders.
  #
  #   [
  #     [
  #       { 'xo_price' => 1.1, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.2, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.3, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.4, 'xo_length' => 4, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.5, 'xo_length' => 5, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
  #     ],
  #     [
  #       { 'xo_price' => 1.4, 'xo_length' => 1, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.3, 'xo_length' => 2, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.2, 'xo_length' => 3, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil }
  #     ],
  #     [
  #       { 'xo_price' => 1.3, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.4, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.5, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
  #     ],
  #     [
  #       { 'xo_price' => 1.4, 'xo_length' => 1, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.3, 'xo_length' => 2, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.2, 'xo_length' => 3, 'xo' => 'o', 'trend' => 'up', 'pattern' => nil }
  #     ],
  #     [
  #       { 'xo_price' => 1.3, 'xo_length' => 1, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.4, 'xo_length' => 2, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.5, 'xo_length' => 3, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil },
  #       { 'xo_price' => 1.6, 'xo_length' => 4, 'xo' => 'x', 'trend' => 'up', 'pattern' => 'double_top' },
  #       { 'xo_price' => 1.7, 'xo_length' => 5, 'xo' => 'x', 'trend' => 'up', 'pattern' => nil }
  #     ]
  #   ]
  def xos(points, options)
    columns = options[:columns] || 3
    keys    = options[:keys] || ['xo_price', 'xo_length', 'xo', 'trend', 'pattern']
    since   = options[:since]

    xos     = []
    xs      = []
    os      = []
    last_xo = points.last['xo']

    points.each do |point|
      next if since && Time.parse(point['candle_at']).utc < Time.parse(since).utc

      case point['xo']
      when 'x'
        xs << point.select { |key, value| keys.include?(key) }

        if last_xo != point['xo']
          xos << os if os.any?
          os = []
        end
      when 'o'
        os << point.select { |key, value| keys.include?(key) }

        if last_xo != point['xo']
          xos << xs if xs.any?
          xs = []
        end
      end

      last_xo = point['xo']
    end

    xos << xs if xs.any?
    xos << os if os.any?
    xs = []
    os = []

    # We need at least 3 complete xo columns!
    raise OandaWorker::IndicatorError, "#{self.class} ERROR. Not enough xo columns to work with. xos: #{xos.size}" if xos.size <= columns.to_i
    xos
  end

  def activity_logging(message)
    data = @data.merge({
      published_at: time_now_utc,
      level:        :primary,
      message:      message
    })
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
  end

  def backtest_logging(message)
    return unless backtesting?
    data = @data.merge({
      published_at: time_now_utc,
      level:        :primary,
      message:      message
    })
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_activity')
  end

  def backtest_exporting(values = {})
    return unless backtesting?
    data = @data.merge(action: 'export_values_to_file', config: config, values: values)
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_backtest')
  end

  def backtest_chart_plotting(values = {})
    return unless backtesting?
    data = @data.merge(action: 'export_chart_plot_values_to_file', config: config, values: values)
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_backtest')
  end

  def backtest_export
    return false unless backtesting?

    trade = oanda_changes['changes']['tradesClosed'].last

    unless trade
      return true unless $redis.get("backtest:transaction:#{oanda_changes['lastTransactionID']}")
      transaction = JSON.parse($redis.get("backtest:transaction:#{oanda_changes['lastTransactionID']}"))
      return true unless transaction['transaction']['tradesClosed']
      trade       = JSON.parse($redis.get("backtest:trade:#{transaction['transaction']['tradesClosed'].first['tradeID']}"))
      trade       = trade['trade']
    end

    return false unless trade

    target_prices     = []
    pos_exit_prices   = []
    pos_total_spreads = []
    type              = trade['initialUnits'].to_i >= 0 ? :long : :short
    pip_price         = OandaApiV20Backtest::INSTRUMENTS[instrument]['pip_price']

    entry_date_time_array = trade['openTime'].split('T')
    exit_date_time_array  = trade['closeTime'].split('T')
    entry_date            = entry_date_time_array[0]
    entry_time            = entry_date_time_array[1].split(':')[0..2].join(':')
    exit_date             = exit_date_time_array[0]
    exit_time             = exit_date_time_array[1].split(':')[0..2].join(':')

    trade['closingTransactionIDs'].each do |id|
      closing_transaction = JSON.parse($redis.get("backtest:transaction:#{id}"))
      opening_transaction = JSON.parse($redis.get("backtest:transaction:#{trade['id']}"))
      order               = JSON.parse($redis.get("backtest:order:#{closing_transaction['transaction']['orderID']}"))
      entry_spread        = (opening_transaction['transaction']['tradeOpened']['halfSpreadCost'].to_f / opening_transaction['transaction']['tradeOpened']['units'].to_f).abs
      exit_spread         = (closing_transaction['transaction']['halfSpreadCost'].to_f / closing_transaction['transaction']['units'].to_f).abs
      spread              = "%.#{round_decimal}f" % (-((entry_spread + exit_spread) / pip_price))

      if order['order']['type'] == 'TAKE_PROFT' || (order['order']['clientExtensions'] && order['order']['clientExtensions']['tag'].include?('take_profit'))
        target_prices.push(order['order']['price'])
      end

      pos_exit_prices.push(closing_transaction['transaction']['price'])
      pos_total_spreads.push(spread)
    end

    oanda_active_orders.each do |order|
      if order['clientExtensions'] && order['clientExtensions']['tag'].include?('take_profit')
        target_prices.push(order['price'])
      end
    end

    if target_prices.empty?
      target_prices.push(trade['takeProfitOrder']['price']) if trade['takeProfitOrder']
    end

    # NOTE: target_prices
    #
    # If by this point we can still not figure out what the target_prices should've been, we will need to calculate this from the backtest_export override function within the strategy itself.
    # This could happen if we didn't use a take profit order on the initial order itself and instead used a separate limit order as the take profit order.
    # We usually get to this point when an order was triggered and immediately closed by its stop loss order.

    [trade, entry_date, entry_time, exit_date, exit_time, target_prices, pos_exit_prices, pos_total_spreads]
  end
end
