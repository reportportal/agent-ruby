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

Feature: Scenarios without background

  @pass_before @pass_after
  Scenario: Everything passes
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Passing step #4

  Scenario: First step fails
    Given Failing step #1
    Then Passing step #2
    And Passing step #3

  Scenario: Middle step fails
    Given Passing step #1
    When Passing step #2
    And Failing step #3
    Then Passing step #4

  Scenario: Last step fails
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Failing step #4

  Scenario: First step undefined
    Given Undefined step
    When Passing step #1
    And Passing step #2
    Then Passing step #3

  Scenario: Middle step undefined
    Given Passing step #1
    When Undefined step
    And Passing step #2
    Then Passing step #3

  Scenario: Last step undefined
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Undefined step

  Scenario: One step fails, then undefined step
    Given Passing step #1
    When Failing step #2
    And Passing step #3
    Then Undefined step

  Scenario: One step fails, then pending step
    Given Passing step #1
    When Failing step #2
    And Passing step #3
    Then Pending step #4

  Scenario: Step with a failing AfterStep hook
    Given Passing step #1
    When Step with failing AfterStep hook
    Then Passing step #3

  @fail_before
  Scenario: Before hook fails
    Given Passing step #1
    Then Passing step #2
    And Passing step #3

  @fail_after
  Scenario: All steps pass, after hook fails
    Given Passing step #1
    Then Passing step #2
    And Passing step #3

  @fail_after
  Scenario: One step fails, after hook fails
    Given Passing step #1
    Then Failing step #2
    And Passing step #3

  Scenario: Step with table
    Given Passing step #1
    Then Passing step with table:
      | foo     | 1       |
      | bar     | 1       |
      | baz     | 2       |
      | quux    | 3       |

  Scenario: Pending step
    When Passing step #1
    Then Pending step #2

  @pass_before @pass_after
  Scenario Outline: Passing outline
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |
    | 5     | 6     |
    | 7     | 8     |

  Scenario Outline: Conditionally passing outline
    When Passing step #1
    Then <status> step #<num>
  Examples:
    | status  | num |
    | Passing | 2   |
    | Failing | 3   |
    | Passing | 4   |
    | Passing | 5   |
    | Failing | 6   |

  Scenario Outline: Failing outline
    When Failing step #1
    Then Passing step #<num>
  Examples:
    | num   |
    | 2     |
    | 3     |
    | 4     |

  Scenario Outline: Outline failing on second step
    When Passing step #1
    Then Failing step #<num>
  Examples:
    | num   |
    | 2     |
    | 3     |
    | 4     |

  @fail_before
  Scenario Outline: Passing outline with failing before hook
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |

  @fail_after
  Scenario Outline: Passing outline with failing after hook
    When Passing step #<num1>
    Then Passing step #<num2>
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |

  Scenario Outline: Outline with undefined step
    When Passing step #<num1>
    Then Undefined step
  Examples:
    | num1  |
    | 1     |
    | 2     |

  Scenario Outline: Outline with failing and undefined step
    When Passing step #<num1>
    Then Failing step #<num2>
    Then Undefined step
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |

  Scenario Outline: Outline with pending step
    When Passing step #<num1>
    Then Pending step #<num2>
  Examples:
    | num1  | num2  |
    | 1     | 2     |
    | 3     | 4     |

  Scenario Outline: Outline with step with table
    Given Passing step #<num1>
    Then Passing step with table:
      | foo     | <num1>  |
      | bar     | <num2>  |
      | baz     | <num3>  |
      | quux    | <num4>  |
  Examples:
    | num1  | num2  | num3  | num4  |
    | 1     | 2     | 3     | 4     |
    | 2     | 4     | 6     | 8     |

  Scenario: Multiline string
    Given Passing step #1
    Then Step with multiline string
    """
    I don't like
    Cucumber
    """

  Scenario Outline: Outline with multiline string
    Given Passing step #1
    Then Step with multiline string
    """
    I <verb>
    Cucumber
    """
  Examples:
    | verb          |
    | don't like    |
    | hate          |
    | despise       |