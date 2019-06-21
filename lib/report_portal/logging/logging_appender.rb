require 'logging'

require_relative '../../reportportal'

module ReportPortal
  # Custom ReportPortal appender for 'logging' gem
  class LoggingAppender < ::Logging::Appender
    def write(event)
      (str, lvl) = if event.instance_of?(::Logging::LogEvent)
                     [layout.format(event), event.level]
                   else
                     [event.to_s, ReportPortal::LOG_LEVELS[:unknown]]
                   end

      ReportPortal.send_log(lvl, str, ReportPortal.now)
    end
  end
end
