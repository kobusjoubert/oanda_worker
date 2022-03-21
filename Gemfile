source 'https://rubygems.org'

ruby '2.4.5'

gem 'dotenv', '~> 2.1'

gem 'bunny', '~> 2.9'
gem 'sneakers', '~> 2.7'
gem 'json', '~> 2.0'
gem 'redis', '~> 3.3'

gem 'attr_encrypted', '~> 3.1'
gem 'http-exceptions_parser', '~> 0.1'
gem 'oanda_api_v20', '~> 2.1'
gem 'oanda_service_api', '2.0.2', git: 'https://github.com/kobusjoubert/oanda_service_api.git'
gem 'aws-sdk-machinelearning', '1.0.0.rc1'

group :development, :backtest, :test do
  gem 'byebug', platform: :mri
end

group :backtest do
  gem 'oanda_api_v20_backtest', '2.0.50', git: 'git@github.com:kobusjoubert/oanda_api_v20_backtest.git'
end
