class AccountUpdate
  REQUIRED_ATTRIBUTES = [:action, :practice, :account].freeze

  attr_accessor  :action, :practice, :account, :access_token, :max_concurrent_trades
  attr_reader    :key_base, :key_access_token

  def initialize(options = {})
    options.symbolize_keys!
    missing_attributes = REQUIRED_ATTRIBUTES - options.keys
    raise ArgumentError, "The #{missing_attributes} attributes are missing" unless missing_attributes.empty?

    options.each do |key, value|
      self.send("#{key}=", value) if self.respond_to?("#{key}=")
    end
  end

  def update_redis_keys
    begin
      update_access_token if access_token
      update_max_concurrent_trades if max_concurrent_trades
    rescue Timeout::Error => e
      raise e
    rescue StandardError => e
      false
    end
    true
  end

  def delete_redis_keys
    begin
      delete_access_token if access_token
      delete_max_concurrent_trades if max_concurrent_trades
    rescue Timeout::Error => e
      raise e
    rescue StandardError => e
      false
    end
    true
  end

  private

  def update_access_token
    Account.new(practice: practice, account: account, access_token: access_token).save
  end

  def delete_access_token
    Account.new(practice: practice, account: account, access_token: access_token).delete
  end

  def update_max_concurrent_trades
    Account.new(practice: practice, account: account, max_concurrent_trades: max_concurrent_trades).save
  end

  def delete_max_concurrent_trades
    Account.new(practice: practice, account: account, max_concurrent_trades: max_concurrent_trades).delete
  end
end
