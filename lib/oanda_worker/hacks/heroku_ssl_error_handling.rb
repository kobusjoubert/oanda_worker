# Hack to retry SSL errors on Heroku
#
# https://stackoverflow.com/questions/50228454/why-am-i-getting-opensslsslsslerror-ssl-read-sslv3-alert-bad-record-mac
#
# This issue has been a difficult one to diagnose due to it's infrequency and inconsistency. We have many reports of it occurring that span destinations, app languages,
# Heroku Dyno configurations, and plenty of other details. This issue has been written up and is being diagnosed by engineers, but again the details have made it almost
# impossible for us to do so.
#
# Additionally, we do not have infrastructure managing outgoing connections. We do have network usage information in raw forms (bytes transferred, number of packets, etc.),
# but unlike incoming connections which has the Heroku Router dealing with requests, outbound connections are all "standard" as provided by our infrastructure provider.
# There is no Heroku-specific infrastructure that deals with outbound connections. The only item of interest there is the virtual interface Dynos use, and by extension the
# Dyno host's network configuration, but again there is nothing special about this. It uses the infrastructure platform provided network configuration necessary for host
# communication.
#
# Neither myself nor engineers have come up with a concise answer for these issues so far, given their inconsistency our current recommendation is that these issues are
# better handled with connection error handling, logging as needed, and retrying.
#
# If you have details on a consistently reproducible way this error occurs it would aid us significantly.
module Hacks
  module HerokuSslErrorHandling
    def perform(&block)
      attempts_left = 3

      begin
        super
      rescue OpenSSL::SSL::SSLError => e
        raise e unless attempts_left > 0
        attempts_left -= 1
        retry
      end
    end
  end
end

class HTTParty::Request
  prepend Hacks::HerokuSslErrorHandling
end
