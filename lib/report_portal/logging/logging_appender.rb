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

require 'logging'

require_relative '../../reportportal'

module ReportPortal
  # Custom ReportPortal appender for 'logging' gem
  class LoggingAppender < ::Logging::Appender
    def write(event)
      (str, lvl) =  if event.instance_of?(::Logging::LogEvent)
                      [layout.format(event), event.level]
                    else
                      [event.to_s, ReportPortal::LOG_LEVELS[:unknown]]
                    end

      ReportPortal.send_log(lvl, str, ReportPortal.now)
    end
  end
end
