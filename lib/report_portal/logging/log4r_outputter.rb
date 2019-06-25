require 'log4r/outputter/outputter'

require_relative '../../reportportal'

module ReportPortal
  # Custom ReportPortal outputter for 'log4r' gem
  class Log4rOutputter < Log4r::Outputter
    def canonical_log(logevent)
      synch { write(Log4r::LNAMES[logevent.level], format(logevent)) }
    end

    def write(level, data)
      ReportPortal.send_log(level, data, ReportPortal.now)
    end
  end
end
