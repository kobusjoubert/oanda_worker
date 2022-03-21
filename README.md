# OandaWorker

Trading strategies configured and initiated from the [Oanda Trader](https://github.com/kobusjoubert/oanda_trader) user interface and executed every 30 seconds by [Oanda Clock](https://github.com/kobusjoubert/oanda_clock).

## Usage

Set your AWS account environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for interacting with AWS when running strategies using machine learning models.

### Development

Start the service

    bin/oanda_worker

### Backtesting

Start the service

    APP_ENV=backtest CANDLE_PATH=~/Documents/Instruments LEVERAGE=30:1 INITIAL_BALANCE=10_000.00 MARGIN_CLOSEOUT_ON_INITIAL_BALANCE=true bin/oanda_worker

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kobusjoubert/oanda_worker.
