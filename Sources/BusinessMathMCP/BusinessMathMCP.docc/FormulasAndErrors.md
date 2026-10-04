# Formulas and Errors

What a formula argument may contain, and what a caller is told when a tool fails.

## Overview

Ten tools take a formula as text — `newton_raphson_optimize`, `gradient_descent_optimize`,
`goal_seek`, `run_monte_carlo`, `sensitivity_analysis`, `tornado_analysis`,
`run_scenario_analysis`, `analyze_scenarios`, and the unregistered
`run_correlated_monte_carlo` and `run_monte_carlo_gpu`. All of them evaluate it with
SwiftMCPServer's `ExpressionEvaluator`, a parser for arithmetic and nothing else.

## Formula syntax

| | |
| :--- | :--- |
| Numbers | `12`, `0.5`, `.5`, `1e6`, `2.5E-3` |
| Operators | `+ - * /`, and `^` for power |
| Grouping | `( )` |
| Functions | `abs` `ceiling` `cos` `exp` `floor` `ln` `log` `log10` `sin` `sqrt` `tan` `trunc` (one argument), `pow` (two), `min` `max` (one or more) |
| Constants | `pi`, `e` |
| Inputs by position | `{0}`, `{1}`, `{2}`, … |
| Inputs by name | see below |

- `^` is exponentiation. It associates to the right — `2 ^ 3 ^ 2` is 512 — and binds tighter
  than a leading minus, so `-2 ^ 2` is −4.
- `/` is floating-point division: `10 / 4` is 2.5.
- `log` is base 10; `ln` is the natural logarithm. Trigonometric functions take radians.
- A formula may be at most 4096 characters and nest at most 64 levels deep.
- Dividing by zero is an error. So is any value — an input, an intermediate result, the answer
  — that is infinite or not a number.

### Inputs by name

| Tool | Names a formula may use |
| :--- | :--- |
| `newton_raphson_optimize`, `goal_seek`, `sensitivity_analysis` | `x` (the same input as `{0}`) |
| `gradient_descent_optimize` | none — `{0}`, `{1}`, … only |
| `run_monte_carlo`, `tornado_analysis`, `run_correlated_monte_carlo`, `run_monte_carlo_gpu` | each input's `name`, when it is an identifier |
| `run_scenario_analysis` | each entry of `inputNames`, when it is an identifier |
| `analyze_scenarios` | each entry of `inputNames`, which **must** be identifiers; `inputs[0]` is accepted as another spelling of `{0}` |

An identifier is a letter or underscore followed by letters, digits and underscores:
`revenue`, `unit_price`, `_t1`. `Sales Volume` is not one. A name is a whole word — `x` is a
variable and `exp(x)` is still a function call; `rate` and `rate_cap` are different variables.
An input named `pi` or `e` takes the place of the constant.

### When a formula cannot be evaluated

The formula is checked once, before anything runs. A character outside the grammar, an
unknown function, a name with no value, or a placeholder with no input is refused with a
message saying which and where:

```
Invalid arguments: formula is not a valid formula. Unexpected '*' at position 3.
Invalid arguments: model is not a valid formula. 'margin' has no value. It is not a supplied variable or a constant.
```

A formula that is well formed can still have no value at a particular point. If that happens
anywhere in a run — at the initial guess, on one Monte Carlo iteration, at one step of a
sweep — the whole call fails and the message names the point:

```
Invalid arguments: calculation has no value at revenue = 100.0, {1} = 100.0. The formula divides by zero.
```

A failed evaluation is never counted as zero.

### Changes from earlier versions

Formulas used to be evaluated by pasting each value into the text and handing the result to
`NSExpression`. Results differ, on purpose:

| Formula | Before | Now |
| :--- | :--- | :--- |
| `2 ^ 3` | 1 — `^` was bitwise XOR | **8** |
| `10 / 4` | 2 — integer literals divided as integers | **2.5** |
| `{0} ^ 2` with `{0}` = −3 | evaluated the text `-3.0 ^ 2` | **9** |
| `exp(x)`, `max(x, 1)` | `x` was replaced inside `exp` and `max` | evaluated |
| `1 / 0` | 0 | an error |
| `2 ** 3` | 8 | an error — write `2 ^ 3` |
| `sum({…})`, `average({…})`, `median({…})`, `random()`, `0x10` | evaluated | an error |
| `pi`, `e` | 0 | 3.14159…, 2.71828… |
| anything that did not parse | the server stopped, or the result was 0 | an error |

## Errors

A failed call returns `isError: true` and a message. The message is one of two kinds.

**A sentence about the request.** A missing or malformed argument, a series that is too
short, a rate outside its range, a matrix that is not square, a calculation that does not
converge for these numbers. These are returned as written.

**A reference.** Anything else — a fault inside the server rather than in the request — is
returned as

```
The server could not complete the request. Reference: err-9f2c41e7a0b3d856
```

and the detail is written to the server's log under that id. The id is random and carries no
information.

Which errors are of the first kind is decided by type: an error reaches the caller only if its
type conforms to SwiftMCPServer's `CallerVisibleError`. The conformances for BusinessMath's
error types are in `CallerVisibleErrors.swift`.
