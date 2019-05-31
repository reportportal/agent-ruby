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
