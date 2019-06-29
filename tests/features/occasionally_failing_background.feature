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
