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
# Report Portal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Report Portal.  If not, see <http://www.gnu.org/licenses/>.

Feature: Scenarios with passing background

  Background: Passing background
    Given Passing step #1
    And Passing step #2

  @pass_before @pass_after
  Scenario: Everything passes
    Given Passing step #3
    When Passing step #4
    And Passing step #5
    Then Passing step #6

  Scenario: One step undefined
    Given Undefined step
    When Passing step #3
    And Passing step #4
    Then Passing step #5

  @fail_before
  Scenario: Before hook fails
    Given Passing step #3
    Then Passing step #4
    And Passing step #5

  @fail_after
  Scenario: After hook fails
    Given Passing step #3
    Then Passing step #4
    And Passing step #5

  @pass_before @pass_after
  Scenario Outline: Passing outline
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 3     | 4     |
    | 5     | 6     |
    | 7     | 8     |
    | 9     | 10    |

  @fail_before
  Scenario Outline: Passing outline with failing before hook
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 3     | 4     |
    | 5     | 6     |

  @fail_after
  Scenario Outline: Passing outline with failing after hook
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 3     | 4     |
    | 5     | 6     |

  Scenario Outline: Failing outline
    When Failing step #3
    Then Passing step #<num>
  Examples:
    | num   |
    | 4     |
    | 5     |
    | 6     |

  Scenario Outline: Outline failing on second step
    When Passing step #3
    Then Failing step #<num>
  Examples:
    | num   |
    | 4     |
    | 5     |
    | 6     |
