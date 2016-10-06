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

require 'pathname'

RSpec.describe 'top level', :ui do
  it 'passes and logs a string and an image', tag1: :value do
    RSpec.configuration.reporter.message("multiline\nstring")

    image = Pathname(__FILE__).dirname.parent + 'assets' + 'crane.png'
    RSpec.configuration.reporter.message(image)
  end

  it 'fails' do
    fail 'error'
  end

  it 'is pending' do
    pending('reason 1')
    fail 'error to make it failed as expected'
  end

  it 'marked as pending but actually it passes' do
    pending
  end

  context 'context' do
    it 'is nested' do
    end

    context 'nested context' do
      it 'is nested twice' do
        fail 'error'
      end
    end
  end
end
