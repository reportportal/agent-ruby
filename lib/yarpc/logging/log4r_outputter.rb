# Copyright 2015 EPAM Systems
# 
# 
# This file is part of YARPC.
# 
# YARPC is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# YARPC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with YARPC.  If not, see <http://www.gnu.org/licenses/>.

require 'log4r/outputter/outputter'

require_relative '../../yarpc'

module YARPC
  # Custom ReportPortal outputter for 'log4r' gem
  class Log4rOutputter < Log4r::Outputter
    def canonical_log(logevent)
      synch { write(Log4r::LNAMES[logevent.level], format(logevent)) }
    end

    def write(level, data)
      YARPC.send_log(level, data, YARPC.now)
    end
  end
end
