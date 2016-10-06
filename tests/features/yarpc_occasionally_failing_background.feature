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

Feature: Scenarios with background that fails sometimes

  Background:
    Given Passing step #1
    And Step that fails on every second execution

  Scenario: Everything passes #1
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Passing step #4

  Scenario: Everything passes #2
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Passing step #4

  Scenario Outline: Passing outline
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |
    | 5     | 6     |
    | 7     | 8     |
