require 'dotenv'
Dotenv.load

require 'attr_encrypted'
require 'http/exceptions_parser'
require 'oanda_api_v20'
require 'oanda_service_api'

require 'oanda_worker/hacks/heroku_ssl_error_handling'

require 'oanda_worker/concerns/backtest'
require 'oanda_worker/concerns/time_methods'
require 'oanda_worker/concerns'

require 'oanda_worker/constants/instruments'
require 'oanda_worker/constants/market_times'
require 'oanda_worker/constants/trigger_conditions'

require 'oanda_worker/core_ext/hash'
require 'oanda_worker/core_ext/time'

require 'oanda_worker/version'
require 'oanda_worker/exceptions'

require 'oanda_worker/account'
require 'oanda_worker/account_update'
require 'oanda_worker/account_update_worker'

require 'oanda_worker/strategy_update'
require 'oanda_worker/strategy_update_worker'

if ENV['APP_ENV'] == 'backtest'
  require 'drb/drb'
  require 'oanda_worker/strategy_bactkest'
  require 'oanda_worker/strategy_backtest_worker'
end

require 'oanda_worker/definitions/account'
require 'oanda_worker/definitions/instrument'
# require 'oanda_worker/definitions/order'
# require 'oanda_worker/definitions/trade'
# require 'oanda_worker/definitions/position'
# require 'oanda_worker/definitions/transaction'
# require 'oanda_worker/definitions/pricing'

require 'oanda_worker/chart'
require 'oanda_worker/charts/candles'

require 'oanda_worker/indicator'
require 'oanda_worker/indicators/average_true_range'
require 'oanda_worker/indicators/moving_average_convergence_divergence'
require 'oanda_worker/indicators/relative_strength_index'
require 'oanda_worker/indicators/standard_deviation'
require 'oanda_worker/indicators/donchian'
require 'oanda_worker/indicators/fractal'
require 'oanda_worker/indicators/funnel_factor'

require 'oanda_worker/overlay'
require 'oanda_worker/overlays/parabolic_stop_and_reverse'
require 'oanda_worker/overlays/bollinger_bands'
require 'oanda_worker/overlays/ichimoku_cloud'
require 'oanda_worker/overlays/exponential_moving_average'
require 'oanda_worker/overlays/weighted_moving_average'
require 'oanda_worker/overlays/simple_moving_average'
require 'oanda_worker/overlays/exhaustion_moving_average'
require 'oanda_worker/overlays/high_low_channel'
require 'oanda_worker/overlays/simple_high_low_channel'
require 'oanda_worker/overlays/highest_highs_lowest_lows'

require 'oanda_worker/pattern'
require 'oanda_worker/patterns/advanced_pattern'
require 'oanda_worker/patterns/gartley'
require 'oanda_worker/patterns/bat'
require 'oanda_worker/patterns/cypher'

# require 'oanda_worker/prediction'
# require 'oanda_worker/predictions/sugar_usd_m1'
# require 'oanda_worker/predictions/natgas_usd_m1'
# require 'oanda_worker/predictions/wtico_usd_m1'
# require 'oanda_worker/predictions/wtico_usd_m10'

require 'oanda_worker/strategy'
# require 'oanda_worker/strategies/steps/strategy_ml'
# require 'oanda_worker/strategies/steps/strategy_ml_sma'
# require 'oanda_worker/strategies/steps/strategy_22XX0'
# require 'oanda_worker/strategies/steps/strategy_22XX1'
# require 'oanda_worker/strategies/steps/strategy_23XX0'
require 'oanda_worker/strategies/steps/strategy_24XX0'
require 'oanda_worker/strategies/steps/strategy_25XX0'
# require 'oanda_worker/strategies/steps/strategy_24XX1'
# require 'oanda_worker/strategies/steps/strategy_33XX1'
# require 'oanda_worker/strategies/steps/strategy_34XX0'
require 'oanda_worker/strategies/steps/strategy_35XX0'
# require 'oanda_worker/strategies/steps/strategy_42XXX'
# require 'oanda_worker/strategies/steps/strategy_45XXX'
# require 'oanda_worker/strategies/steps/strategy_46XX0'
# require 'oanda_worker/strategies/steps/strategy_46XX1'
# require 'oanda_worker/strategies/steps/strategy_46XX2'
# require 'oanda_worker/strategies/steps/strategy_47XX0'
# require 'oanda_worker/strategies/steps/strategy_47XX1'
# require 'oanda_worker/strategies/steps/strategy_47XX2'
# require 'oanda_worker/strategies/steps/strategy_48XX0'
# require 'oanda_worker/strategies/steps/strategy_48XX1'
# require 'oanda_worker/strategies/steps/strategy_48XX2'
# require 'oanda_worker/strategies/steps/strategy_49XX1'
# require 'oanda_worker/strategies/steps/strategy_60XX0'
# require 'oanda_worker/strategies/steps/strategy_61XX0'
# require 'oanda_worker/strategies/steps/strategy_61XX1'
# require 'oanda_worker/strategies/steps/strategy_62XX0'
# require 'oanda_worker/strategies/steps/strategy_62XX1'
# require 'oanda_worker/strategies/steps/strategy_63XX0'
# require 'oanda_worker/strategies/steps/strategy_70XX0'
# require 'oanda_worker/strategies/steps/strategy_71XX0'
# require 'oanda_worker/strategies/steps/strategy_72XX0'
# require 'oanda_worker/strategies/steps/strategy_73XX0'
# require 'oanda_worker/strategies/steps/strategy_74XX0'
# require 'oanda_worker/strategies/steps/strategy_75XX0'
require 'oanda_worker/strategies/steps/strategy_8XXX0'
require 'oanda_worker/strategies/steps/strategy_8XXX1'
require 'oanda_worker/strategies/steps/strategy_8XXX2'
require 'oanda_worker/strategies/steps/strategy_80XX0'
require 'oanda_worker/strategies/steps/strategy_80XX1'
require 'oanda_worker/strategies/steps/strategy_80XX2'

Dir[File.expand_path('oanda_worker/strategies/settings/*.rb', File.dirname(__FILE__))].each do |file|
  require file
end

# Strategy Naming.
# Strategy10000
# |    10    |       000 / 001      |
# | strategy | instrument & version |

# Dummy Strategy.
# require 'oanda_worker/strategies/strategy_00908' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_00930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_00914' # SUGAR_USD
# require 'oanda_worker/strategies/strategy_00910' # SOYBN_USD
# require 'oanda_worker/strategies/strategy_00928' # WHEAT_USD
# require 'oanda_worker/strategies/strategy_00902' # CORN_USD

# Initial Strategies.
# require 'oanda_worker/strategies/strategy_01908' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_01909' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_01914' # SUGAR_USD
# require 'oanda_worker/strategies/strategy_02908' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_02914' # SUGAR_USD
# require 'oanda_worker/strategies/strategy_02930' # WTICO_USD

# Machine Learning Strategies.
# require 'oanda_worker/strategies/strategy_10914' # SUGAR_USD
# require 'oanda_worker/strategies/strategy_10915' # SUGAR_USD
# require 'oanda_worker/strategies/strategy_10908' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_10909' # NATGAS_USD
# require 'oanda_worker/strategies/strategy_10930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_11930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_11931' # WTICO_USD

# Moving Average Strategies.
# require 'oanda_worker/strategies/strategy_20930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_20931' # WTICO_USD
# require 'oanda_worker/strategies/strategy_21930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_21931' # WTICO_USD
# require 'oanda_worker/strategies/strategy_22058' # EUR_USD
# require 'oanda_worker/strategies/strategy_23058' # EUR_USD
require 'oanda_worker/strategies/strategy_24000' # AUD_CAD
require 'oanda_worker/strategies/strategy_24002' # AUD_CHF
require 'oanda_worker/strategies/strategy_24006' # AUD_JPY
require 'oanda_worker/strategies/strategy_24008' # AUD_NZD
require 'oanda_worker/strategies/strategy_24012' # AUD_USD
require 'oanda_worker/strategies/strategy_24014' # CAD_CHF
require 'oanda_worker/strategies/strategy_24018' # CAD_JPY
require 'oanda_worker/strategies/strategy_24024' # CHF_JPY
require 'oanda_worker/strategies/strategy_24028' # EUR_AUD
require 'oanda_worker/strategies/strategy_24030' # EUR_CAD
require 'oanda_worker/strategies/strategy_24032' # EUR_CHF
require 'oanda_worker/strategies/strategy_24038' # EUR_GBP
require 'oanda_worker/strategies/strategy_24044' # EUR_JPY
require 'oanda_worker/strategies/strategy_24048' # EUR_NZD
require 'oanda_worker/strategies/strategy_24058' # EUR_USD
require 'oanda_worker/strategies/strategy_24062' # GBP_AUD
require 'oanda_worker/strategies/strategy_24064' # GBP_CAD
require 'oanda_worker/strategies/strategy_24066' # GBP_CHF
require 'oanda_worker/strategies/strategy_24070' # GBP_JPY
require 'oanda_worker/strategies/strategy_24072' # GBP_NZD
require 'oanda_worker/strategies/strategy_24078' # GBP_USD
require 'oanda_worker/strategies/strategy_24084' # NZD_CAD
require 'oanda_worker/strategies/strategy_24086' # NZD_CHF
require 'oanda_worker/strategies/strategy_24090' # NZD_JPY
require 'oanda_worker/strategies/strategy_24094' # NZD_USD
require 'oanda_worker/strategies/strategy_24104' # USD_CAD
require 'oanda_worker/strategies/strategy_24106' # USD_CHF
require 'oanda_worker/strategies/strategy_24120' # USD_JPY
require 'oanda_worker/strategies/strategy_24138' # USD_ZAR

require 'oanda_worker/strategies/strategy_25012' # AUD_USD
require 'oanda_worker/strategies/strategy_25044' # EUR_JPY
require 'oanda_worker/strategies/strategy_25058' # EUR_USD
require 'oanda_worker/strategies/strategy_25078' # GBP_USD
require 'oanda_worker/strategies/strategy_25094' # NZD_USD
require 'oanda_worker/strategies/strategy_25104' # USD_CAD
require 'oanda_worker/strategies/strategy_25106' # USD_CHF

# Time Entry Strategies (SPAM etc).
# require 'oanda_worker/strategies/strategy_30058' # EUR_USD
# require 'oanda_worker/strategies/strategy_30059' # EUR_USD
# require 'oanda_worker/strategies/strategy_31120' # USD_JPY
# require 'oanda_worker/strategies/strategy_32058' # EUR_USD
# require 'oanda_worker/strategies/strategy_32059' # EUR_USD
# require 'oanda_worker/strategies/strategy_33059' # EUR_USD
# require 'oanda_worker/strategies/strategy_34058' # EUR_USD
require 'oanda_worker/strategies/strategy_35058' # EUR_USD

# Support & Resistance / Channels Strategies.
# require 'oanda_worker/strategies/strategy_40058' # EUR_USD
# require 'oanda_worker/strategies/strategy_41058' # EUR_USD
# require 'oanda_worker/strategies/strategy_41120' # USD_JPY

# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_42#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_45#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# Trend Strategies.
# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_46#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_47#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_48#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# INSTRUMENTS.each do |key, value|
#   begin
#     require "oanda_worker/strategies/strategy_49#{value['worker_code']}"
#   rescue LoadError
#   end
# end

# Candle Trading.
# require 'oanda_worker/strategies/strategy_50058' # EUR_USD

# Channel Strategies.
# require 'oanda_worker/strategies/strategy_60058' # EUR_USD
# require 'oanda_worker/strategies/strategy_60930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_61058' # EUR_USD
# require 'oanda_worker/strategies/strategy_61059' # EUR_USD
# require 'oanda_worker/strategies/strategy_62058' # EUR_USD
# require 'oanda_worker/strategies/strategy_62059' # EUR_USD
# require 'oanda_worker/strategies/strategy_62930' # WTICO_USD
# require 'oanda_worker/strategies/strategy_63058' # EUR_USD

# Support & Resistance.
# require 'oanda_worker/strategies/strategy_70058' # EUR_USD
# require 'oanda_worker/strategies/strategy_71058' # EUR_USD
# require 'oanda_worker/strategies/strategy_72058' # EUR_USD
# require 'oanda_worker/strategies/strategy_73058' # EUR_USD
# require 'oanda_worker/strategies/strategy_74058' # EUR_USD
# require 'oanda_worker/strategies/strategy_75058' # EUR_USD

# Advanced Patterns.
require 'oanda_worker/strategies/strategy_80000' # AUD_CAD
require 'oanda_worker/strategies/strategy_80002' # AUD_CHF
require 'oanda_worker/strategies/strategy_80006' # AUD_JPY
require 'oanda_worker/strategies/strategy_80008' # AUD_NZD
require 'oanda_worker/strategies/strategy_80012' # AUD_USD
require 'oanda_worker/strategies/strategy_80014' # CAD_CHF
require 'oanda_worker/strategies/strategy_80018' # CAD_JPY
require 'oanda_worker/strategies/strategy_80024' # CHF_JPY
require 'oanda_worker/strategies/strategy_80028' # EUR_AUD
require 'oanda_worker/strategies/strategy_80030' # EUR_CAD
require 'oanda_worker/strategies/strategy_80032' # EUR_CHF
require 'oanda_worker/strategies/strategy_80038' # EUR_GBP
require 'oanda_worker/strategies/strategy_80044' # EUR_JPY
require 'oanda_worker/strategies/strategy_80048' # EUR_NZD
require 'oanda_worker/strategies/strategy_80058' # EUR_USD
require 'oanda_worker/strategies/strategy_80062' # GBP_AUD
require 'oanda_worker/strategies/strategy_80064' # GBP_CAD
require 'oanda_worker/strategies/strategy_80066' # GBP_CHF
require 'oanda_worker/strategies/strategy_80070' # GBP_JPY
require 'oanda_worker/strategies/strategy_80072' # GBP_NZD
require 'oanda_worker/strategies/strategy_80078' # GBP_USD
require 'oanda_worker/strategies/strategy_80084' # NZD_CAD
require 'oanda_worker/strategies/strategy_80086' # NZD_CHF
require 'oanda_worker/strategies/strategy_80090' # NZD_JPY
require 'oanda_worker/strategies/strategy_80094' # NZD_USD
require 'oanda_worker/strategies/strategy_80104' # USD_CAD
require 'oanda_worker/strategies/strategy_80106' # USD_CHF
require 'oanda_worker/strategies/strategy_80120' # USD_JPY
require 'oanda_worker/strategies/strategy_80138' # USD_ZAR

require 'oanda_worker/strategy_step'
require 'oanda_worker/strategy_run'
require 'oanda_worker/strategy_run_all_worker'
require 'oanda_worker/strategy_run_one_worker'

# --000 AUD_CAD
# --002 AUD_CHF
# --004 AUD_HKD
# --006 AUD_JPY
# --008 AUD_NZD
# --010 AUD_SGD
# --012 AUD_USD
# --014 CAD_CHF
# --016 CAD_HKD
# --018 CAD_JPY
# --020 CAD_SGD
# --022 CHF_HKD
# --024 CHF_JPY
# --026 CHF_ZAR
# --028 EUR_AUD
# --030 EUR_CAD
# --032 EUR_CHF
# --034 EUR_CZK
# --036 EUR_DKK
# --038 EUR_GBP
# --040 EUR_HKD
# --042 EUR_HUF
# --044 EUR_JPY
# --046 EUR_NOK
# --048 EUR_NZD
# --050 EUR_PLN
# --052 EUR_SEK
# --054 EUR_SGD
# --056 EUR_TRY
# --058 EUR_USD
# --060 EUR_ZAR
# --062 GBP_AUD
# --064 GBP_CAD
# --066 GBP_CHF
# --068 GBP_HKD
# --070 GBP_JPY
# --072 GBP_NZD
# --074 GBP_PLN
# --076 GBP_SGD
# --078 GBP_USD
# --080 GBP_ZAR
# --082 HKD_JPY
# --084 NZD_CAD
# --086 NZD_CHF
# --088 NZD_HKD
# --090 NZD_JPY
# --092 NZD_SGD
# --094 NZD_USD
# --096 SGD_CHF
# --098 SGD_HKD
# --100 SGD_JPY
# --102 TRY_JPY
# --104 USD_CAD
# --106 USD_CHF
# --108 USD_CNH
# --110 USD_CZK
# --112 USD_DKK
# --114 USD_HKD
# --116 USD_HUF
# --118 USD_INR
# --120 USD_JPY
# --122 USD_MXN
# --124 USD_NOK
# --126 USD_PLN
# --128 USD_SAR
# --130 USD_SEK
# --132 USD_SGD
# --134 USD_THB
# --136 USD_TRY
# --138 USD_ZAR
# --140 ZAR_JPY
#  
# --600 XAG_AUD
# --602 XAG_CAD
# --604 XAG_CHF
# --606 XAG_EUR
# --608 XAG_GBP
# --610 XAG_HKD
# --612 XAG_JPY
# --614 XAG_NZD
# --616 XAG_SGD
# --618 XAG_USD
# --620 XAU_AUD
# --622 XAU_CAD
# --624 XAU_CHF
# --626 XAU_EUR
# --628 XAU_GBP
# --630 XAU_HKD
# --632 XAU_JPY
# --634 XAU_NZD
# --636 XAU_SGD
# --638 XAU_USD
# --640 XAU_XAG
# --642 XCU_USD
# --644 XPD_USD
# --646 XPT_USD
#  
# --800 AU200_AUD
# --802 CH20_CHF
# --804 CN50_USD
# --806 DE30_EUR
# --808 EU50_EUR
# --810 FR40_EUR
# --812 HK33_HKD
# --814 IN50_USD
# --816 JP225_USD
# --818 NL25_EUR
# --820 SG30_SGD
# --822 UK100_GBP
# --824 US2000_USD
# --826 US30_USD
#  
# --900 BCO_USD
# --902 CORN_USD
# --904 DE10YB_EUR
# --906 NAS100_USD
# --908 NATGAS_USD
# --910 SOYBN_USD
# --912 SPX500_USD
# --914 SUGAR_USD
# --916 TWIX_USD
# --918 UK10YB_GBP
# --920 USB02Y_USD
# --922 USB05Y_USD
# --924 USB10Y_USD
# --926 USB30Y_USD
# --928 WHEAT_USD
# --930 WTICO_USD
