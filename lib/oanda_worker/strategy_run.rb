class StrategyRun
  REQUIRED_ATTRIBUTES = [:action, :key_base, :strategies].freeze

  attr_accessor :action, :key_base, :strategies, :backtest_index, :backtest_time
  attr_reader   :oanda_client, :oanda_service_client, :aws_client, :practice, :practice_or_live, :account

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end

    @practice_or_live = key_base.split(':')[0]
    @account          = key_base.split(':')[2]
    @practice         = practice_or_live == 'practice' ? true : false

    if backtesting? && !backtest_time.instance_of?(Time)
      begin
        @backtest_time = Time.parse(backtest_time).utc
      rescue ArgumentError, TypeError
        @backtest_time = Time.at(backtest_time.to_i).utc
      end
    end

    oanda_service_options = {
      email:                'oanda_worker@translate3d.com',
      authentication_token: ENV['OANDA_SERVICE_AUTHENTICATION_TOKEN'],
      environment:          ENV['APP_ENV'] || 'development'
    }

    oanda_service_options.merge!(backtest_time: backtest_time.iso8601(9)) if backtesting?
    @oanda_service_client = OandaServiceApi.new(oanda_service_options)

    if backtesting?
      @oanda_client   = OandaApiV20Backtest.new(backtest_index: backtest_index, backtest_time: backtest_time)
    else
      @worker_account = Account.find_by!(practice: practice, account: account)
      @oanda_client   = OandaApiV20.new(access_token: @worker_account.access_token, practice: @worker_account.practice)
    end

    @aws_client = Aws::MachineLearning::Client.new
  end

  # qw_strategy_run_all.
  def run_strategies
    strategies.each do |strategy|
      strategy_key_base = "#{key_base}:#{strategy}"
      step              = $redis.get("#{strategy_key_base}:step")

      # Allow 3 seconds for a locked strategy to be freed before we unlock it again.
      # Strategies sometimes gets left in a locked state when the servers are restarted each night.
      if locked?(strategy, step)
        if backtesting?
          sleep 2 
        else
          Thread.new do
            sleep 3
            unlock!(strategy)
            $logger.warn "LOCKED! -> ULOCKED! run_strategies. Trying to run a locked strategy step. Unlocked after 3 seconds. step: #{step}. key_base: #{strategy_key_base}"

            data = { key_base: strategy_key_base, oanda_client: oanda_client, oanda_service_client: oanda_service_client, aws_client: aws_client, backtest_index: backtest_index, backtest_time: backtest_time }
            StrategyStep.new(data).run_strategy_at_step
          end.join
        end

        next
      end

      data = { key_base: strategy_key_base, oanda_client: oanda_client, oanda_service_client: oanda_service_client, aws_client: aws_client, backtest_index: backtest_index, backtest_time: backtest_time }
      StrategyStep.new(data).run_strategy_at_step
    end

    true
  end

  # qw_strategy_run_one.
  def run_strategy
    strategy          = strategies.first
    strategy_key_base = "#{key_base}:#{strategy}"
    step              = $redis.get("#{strategy_key_base}:step")

    # Allow 3 seconds for a locked strategy to be freed before we call it quits and don't run this step.
    if locked?(strategy, step)
      for i in 1..3
        if i == 3
          $logger.warn "LOCKED! run_strategy. Trying to run a locked strategy step. step: #{step}. key_base: #{strategy_key_base}"
          return true # false, could be dangerous and cause an endless loop!
        end

        sleep i
        locked?(strategy, step) ? next : break
      end
    end

    data = { key_base: strategy_key_base, oanda_client: oanda_client, oanda_service_client: oanda_service_client, aws_client: aws_client, backtest_index: backtest_index, backtest_time: backtest_time }
    StrategyStep.new(data).run_strategy_at_step

    true
  end

  private

  def locked?(strategy, step)
    $redis.smembers("#{key_base}:#{strategy}:step_locks").any?
    # $redis.sismember("#{key_base}:#{strategy}:step_locks", step)
  end

  def unlock!(strategy)
    $redis.del("#{key_base}:#{strategy}:step_locks")
    return true
  end
end
