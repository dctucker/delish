# Delish language description

Delish is a line-oriented scripting language. A line may contain a statement or a block followed by a comment.
Comments begin with the `#` character.

## Keywords

These are reserved words that cannot be used as a function name.

| Keyword    | Description           |
|------------|-----------------------|
| `if`       | Conditional           |
| `while`    | Pre-test loop         |
| `do`       | Post-test loop        |
| `for`      | Iterator loop         |
| `in`       | Input stream          |
| `out`      | Output stream         |
| `err`      | Error stream          |
| `include`  | Inclusion directive   |
| `true`     | Boolean literal       |
| `false`    | Boolean literal       |
| `env`      | Environment variable  |
| `arg`      | Argument variable     |
| `local`    | Local variable        |
| `return`   | Return statement      |
| `break`    | Loop exit             |
| `continue` | Early next iteration  |
| `async`    | Background process    |
| `redir`    | Stream redirection    |
| `and`      | Logical conjunction   |
| `or`       | Logical disjunction   |
| `not`      | Logical negation      |
| `push`     | Stack addition        |
| `pop`      | Stack removal         |
| `open`     | File handle acquire   |
| `close`    | File handle release   |
| `json`     | JSON data             |
| `run`      | Process execution     |
| `sub`      | Subshell              |

## Operators

Operators are symbols that have specific usage and meaning when placed next to other identifiers.

| Operator | Description             |
|----------|-------------------------|
| Assignment                         |
| `=`      | Direct assign           |
| `|=`     | Default assign          |
| `+=`     | Append                  |
| `-=`     | Remove                  |
| Redirection                        |
| `>>`     | Redirect append         |
| `<`      | Redirect read           |
| `>`      | Redirect write          |
| `<>`     | Redirect duplex         |
| Comparison                         |
| `>=`     | Greater or equal        |
| `>`      | Greater                 |
| `<=`     | Less or equal           |
| `<`      | Less                    |
| `==`     | Equality                |
| `!=`     | Inequality              |
| `=~`     | Matching                |
| Array / object access              |
| `.`      | Dereferencing           |
| `:`      | Key/value separator     |
| `,`      | Value separator         |
| Mathematical                       |
| `+`      | Addition                |
| `-`      | Subtraction             |
| `*`      | Multiplication          |
| `/`      | Division                |
| `%`      | Modulo                  |

## Identifiers and variables

Identifiers must start with letters, and can contain numbers, underscores and hyphens.
Variables start with a `$`.

## Paths

Path names must begin with a dot or a slash.
