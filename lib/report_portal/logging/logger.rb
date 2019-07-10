require 'logger'

module ReportPortal
  class << self
    # Monkey-patch for built-in Logger class
    def patch_logger
      Logger.class_eval do
        alias_method :orig_add, :add
        alias_method :orig_write, :<<
        def add(severity, message = nil, progname = nil, &block)
          ret = orig_add(severity, message, progname, &block)

          unless severity < @level
            progname ||= @progname
            if message.nil?
              if block_given?
                message = yield
              else
                message = progname
                progname = @progname
              end
            end
            ReportPortal.send_log(format_severity(severity), format_message(format_severity(severity), Time.now, progname, message.to_s), ReportPortal.now)
          end
          ret
        end

        def <<(msg)
          ret = orig_write(msg)
          ReportPortal.send_log(ReportPortal::LOG_LEVELS[:unknown], msg.to_s, ReportPortal.now)
          ret
        end
      end
    end
  end
end
