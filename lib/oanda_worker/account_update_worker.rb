class AccountUpdateWorker
  include Sneakers::Worker
  from_queue :qw_account_update

  def work(msg)
    data = JSON.parse(msg)
    AccountUpdate.new(data).send(data[:action]) ? ack! : requeue!
  rescue Timeout::Error
    Sneakers.logger.error "TIMEOUT ERROR! data. #{data}"
    requeue!
  end
end
