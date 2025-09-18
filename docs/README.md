# Delish language description

Delish is a line-oriented scripting language. A line may contain a statement or a block followed by a comment.
Comments begin with the `#` character.

## Data types

| Type       | Description                         |
|------------|-------------------------------------|
| Arg        | Arguments and flags                 |
| Boolean    | Logical true or false               |
| Identifier | Object key or function name         |
| Stream     | Standard input/output/error streams |
| Variable   | Reference to runtime memory         |
| Integer    | Numbers 0-9                         |
| String     | Collection of characters            |
| Path       | Absolute and relative filenames     |
| Regex      | Regular expressions                 |
| Array      | Zero-indexed collection             |
| Object     | Key/value pair collection           |

### Casts

Casting (converting between types) is possible for some types. The following table shows which conversions are possible:

| dest / src | String     | Identifier | Variable   | Arg        | Path       | Integer    | Boolean    | Array      | Object     | Regex      | Stream     |
|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|
| String     |     -      |   id.id    | v.varName  |a.name a.val|  p.strVal  |   i.itoa   |   "true"   | a.join " " |  "[k: v]"  |  r.strVal  |   s.name   |
| Identifier | DKIdent(s) |     -      |  DKId(v)   |DKId(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
| Variable   |  DKVar(s)  |  DKVar(id) |     -      | Var(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
| Arg        | -s / --str | -id / --id | --varName  |     -      |     X      |     X      |     X      |     X      |     X      |     X      |     X      |
| Path       |    ./s     |   ./id     |     X      |  ./a.name  |     -      |    ./i     |   /bin/b   | a.join "/" |     X      |     X      | s.filename |
| Integer    |   s.int    |     X      |     X      |     X      |     X      |     -      |   0 / 1    |   a.len    |  keys.len  |     X      |  s.intVal  |
| Boolean    | s.len > 0  |  id.exists | ! v.isNone | ! a.isNone |  p.exists  |   i != 0   |     -      | a.len > 0  |keys.len > 0|     X      |  s.exists  |
| Array      |  s.split   |   @[id]    |    @[v]    |    @[a]    |  p.split   |    @[i]    | @[] / @[b] |     -      | @[@[k, v]] |  r.rules   |     X      |
| Object     |  s.parse   | [name:val] | [name:val] | [name:val] |     X      | ["int": i] |["bool": b] |[0:x,1:y...]|     -      |     X      | intval:name|
| Regex      |  s.parse   |     X      |     X      |     X      |     X      |     X      |     X      | /(x)|(y)/  |     X      |     -      |     X      |
| Stream     |   buffer   |     X      |     X      |     X      |     X      |   fds[i]   |     X      |   buffer   |     X      |     X      |     -      |

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
|          | *Assignment*            |
| `=`      | Direct assign           |
| `\|=`    | Default assign          |
| `+=`     | Append                  |
| `-=`     | Remove                  |
|          |                         |
|          | *Redirection*           |
| `>>`     | Redirect append         |
| `<`      | Redirect read           |
| `>`      | Redirect write          |
| `<>`     | Redirect duplex         |
|          |                         |
|          | *Comparison*            |
| `>=`     | Greater or equal        |
| `>`      | Greater                 |
| `<=`     | Less or equal           |
| `<`      | Less                    |
| `==`     | Equality                |
| `!=`     | Inequality              |
| `=~`     | Matching                |
|          |                         |
|          | *Array / object access* |
| `.`      | Dereferencing           |
| `:`      | Key/value separator     |
| `,`      | Value separator         |
|          |                         |
|          | *Mathematical*          |
| `+`      | Addition                |
| `-`      | Subtraction             |
| `*`      | Multiplication          |
| `/`      | Division                |
| `%`      | Modulo                  |

## Identifiers and variables

Identifiers must start with letters, and can contain numbers, underscores and hyphens. Identifiers can be used as lookup values when dereferencing objects and arrays.

Variables start with a `$`. Variables can also be used as lookup values.

## Arguments and flags

Arguments are always declared. This rule applies to both scripts and functions alike, and argument declarations will normally appear as the first few lines of a block. This encourages self-documenting code.

Expected arguments are declared using the `arg` keyword. For string arguments, the variable name will be specified:
```
arg $message
```

Flags start with `-`. Long flags start with an additional `-`. They are also declared using the `arg` keyword:
```
arg -k --key
```

To specify a default value for an argument, use the `|=` assign default operator:
```
arg $message   |= ""
arg -key --key |= false
```

## Strings

Strings are collections of characters. Single-line string literals use '`' single quotes or `"` double quotes, while multi-line string literals use `"""` triple quotes.

## Paths

Path names must begin with a dot or a slash.

## Blocks

Blocks begin with a keyword followed by `{`, some code, and finally `}`.

## RegEx

Regular expression literals use the `r/.../` syntax. They can be checked against a string using the `=~` matching operator.

## Objects and Arrays

Arrays and objects are similar in function. Objects are composed of key/value pairs, and arrays are generally treated as objects with zero-indexed integer keys.

To create and assign an object, use the `[` `]` symbols. Let's create an empty object:
```
$obj = []
```

Now, let's create an array with two flags as elements:
```
$arr = [
  --list
  --color
]
```

Dereferencing an object is done by using the `.` operator. Let's print the second element of the array we created:
```
out $arr.1
```

## Functions

Functions are defined as an identifier followed by a block of code. Here is a simple "hello world" function:
```
hello = {
  out "Hello world"
}
```

Functions can receive arguments, which must be declared. Let's make our function accept an argument and print it out:
```
hello = {
  arg $message
  out $message
}
```

Functions are called by name, followed by any arguments:
```
func "Hello world"
```

