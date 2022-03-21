class StrategyBacktest
  REQUIRED_ATTRIBUTES = [:action, :practice, :account, :strategy, :config].freeze

  attr_accessor :action, :practice, :account, :strategy, :config, :values
  attr_reader   :key_base

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end

    @key_base = "#{practice ? 'practice' : 'live'}:accounts:#{account}:strategies:#{strategy}"
    @data     = { practice: practice, account: account, strategy: strategy }
  end

  class << self
    def total_backtest_candles
      $redis.get('backtest:total_backtest_candles').to_i
    end
  end

  def start_backtest_server_and_start_queueing
    $redis.del($redis.keys('backtest:*')) unless $redis.keys('backtest:*').empty?
    start_backtest_server
    sleep 2
    start_backtest_queueing
    true
  end

  def stop_backtest_server_and_cleanup
    remove_backtest_queued
    sleep 5
    stop_backtest_server
    $redis.del($redis.keys('backtest:*')) unless $redis.keys('backtest:*').empty?
    data = { practice: practice, account: account, message: 'Backtest server stopped!', level: :success, replace: false }
    $rabbitmq_exchange.publish(data.to_json, routing_key: 'qt_strategy_warning')
    true
  end

  def export_values_to_file
    instrument  = Object.const_get("Strategies::Strategy#{strategy}")::INSTRUMENT
    granularity = Definitions::Instrument.candlestick_granularity(config['chart_interval'].to_i)
    export_path = ENV['EXPORT_PATH'] || "#{Dir.home}/Documents/Backtest"
    file_name   = "#{instrument}_#{granularity}.csv"

    Dir.mkdir(export_path) unless Dir.exist?(export_path)
    file = File.open("#{export_path}/#{file_name}", 'a')
    file.write([instrument, granularity].join("\t") + "\t")
    file.write(values.values.join("\t"))
    file.write("\n")
    file.close
    true
  end

  def export_chart_plot_values_to_file
    instrument  = Object.const_get("Strategies::Strategy#{strategy}")::INSTRUMENT
    granularity = Definitions::Instrument.candlestick_granularity(config['chart_interval'].to_i)
    export_path = ENV['CHART_PLOT_PATH'] || "#{Dir.home}/Development/Ruby/oanda_trader/public/backtest"
    file_name   = "#{instrument}_#{granularity}_TV.txt"

    Dir.mkdir(export_path) unless Dir.exist?(export_path)
    file = File.open("#{export_path}/#{file_name}", 'a')
    # file.write([instrument, granularity].join("\t") + "\t")
    file.write(values.values.join(';'))
    file.write("\n")
    file.close
    true
  end

  private

  def start_backtest_server
    instrument  = Object.const_get("Strategies::Strategy#{strategy}")::INSTRUMENT
    granularity = Definitions::Instrument.candlestick_granularity(config['chart_interval'].to_i)
    DRb.start_service(OandaApiV20Backtest::CandleServer::URI, OandaApiV20Backtest::CandleServer.new(instrument: instrument, granularity: granularity))
  end

  def stop_backtest_server
    DRb.stop_service
  end

  def start_backtest_queueing
    candles_required  = Object.const_get("Strategies::Strategy#{strategy}")::CANDLES_REQUIRED
    instrument        = Object.const_get("Strategies::Strategy#{strategy}")::INSTRUMENT
    granularity       = Definitions::Instrument.candlestick_granularity(config['chart_interval'].to_i)
    candle_path       = ENV['CANDLE_PATH'] || "#{Dir.home}/Documents/Instruments"
    instrument_path   = "#{candle_path}/#{instrument}_#{granularity}"

    alert_data = { practice: practice, account: account, message: '', level: :info, replace: true }
    candles    = []

    Dir.entries(instrument_path).sort.each do |item|
      next if item == '.' || item == '..' || item == '.DS_Store'

      key = item.split('.')[0]

      File.open("#{instrument_path}/#{item}").each do |line|
        line_candles = JSON.parse(line)['candles']
        line_candles = line_candles.map{ |candle| candle if candle['time'].split('T')[0] == key }.compact
        candles      << line_candles
      end
    end

    candles.flatten!
    # candles.uniq! # This should already be unique after we looped through the files above.

    total_candles = candles.count
    $redis.set('backtest:total_backtest_candles', total_candles) # Used for the progress bar.

    for i in candles_required..total_candles - 1
      $rabbitmq_exchange.publish(alert_data.merge(percentage: (i.to_f / total_candles.to_f * 100).ceil, level: :info).to_json, routing_key: 'qt_strategy_progress') if i % (total_candles / 100) == 0

      begin
        backtest_time = Time.parse(candles[i]['time']).utc
      rescue ArgumentError, TypeError
        backtest_time = Time.at(candles[i]['time'].to_i).utc
      end

      data = {
        action:         'run_strategies',
        key_base:       key_base.split(':')[0..3].join(':'),
        strategies:     [strategy],
        backtest_index: i,
        backtest_time:  backtest_time.utc.iso8601(9) # (backtest_time + config['chart_interval'].to_i).utc.iso8601(9)
      }

      $rabbitmq_exchange.publish(data.to_json, routing_key: 'qw_strategy_run_all')
    end
  end

  def remove_backtest_queued
    url_publisher = ENV['CLOUDAMQP_URL'] || 'amqp://guest:guest@localhost:5672'
    rabbitmq_connection = Bunny.new(url_publisher)
    rabbitmq_connection.start
    rabbitmq_channel = rabbitmq_connection.create_channel
    rabbitmq_exchange = rabbitmq_channel.direct('oanda_app', durable: true)
    qw_strategy_run_all = rabbitmq_channel.queue('qw_strategy_run_all', durable: true, auto_delete: false)
    qw_strategy_run_all.purge
    true
  end
end
