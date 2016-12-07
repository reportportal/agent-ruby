# Copyright 2015 EPAM Systems
# 
# 
# This file is part of Report Portal.
# 
# Report Portal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ReportPortal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with Report Portal.  If not, see <http://www.gnu.org/licenses/>.

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
