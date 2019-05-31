Feature: Scenarios with failing background

  Background:
    Given Passing step #1
    And Failing step #2

  @pass_before @pass_after
  Scenario: Everything passes
    Given Passing step #1
    When Passing step #2
    And Passing step #3
    Then Passing step #4

  Scenario: One step undefined
    Given Undefined step
    When Passing step #1
    And Passing step #2
    Then Passing step #3

  @fail_before
  Scenario: Before hook fails
    Given Passing step #1
    Then Passing step #2
    And Passing step #3

  @fail_after
  Scenario: After hook fails
    Given Passing step #1
    Then Passing step #2
    And Passing step #3

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
