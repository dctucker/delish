# Delish language description

Delish is a line-oriented scripting language. A line may contain a statement or a block followed by a comment.
Comments begin with the `#` character.

Full grammar [here](https://github.com/dctucker/delish/blob/main/src/language/delish.packcc)

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

| <ins>from</ins> ➡️<br/>to ⬇️ | String<br/>&nbsp; | Identifier<br/>&nbsp; | Variable<br/>&nbsp; | Arg<br/>&nbsp;  | Path<br/>&nbsp; | Integer<br/>&nbsp; | Boolean<br/>&nbsp; | Array<br/>&nbsp; | Object<br/>&nbsp; | Regex<br/>&nbsp; | Stream<br/>&nbsp; |
|-----------:|:------:|:----------:|:--------:|:----:|:----:|:-------:|:-------:|:-----:|:------:|:-----:|:------:|
| String     |     =  |   :ok:     |   :ok:   | :ok: | :ok: |   :ok:  |   :ok:  |  :ok: |   :ok: |  :ok: |   :ok: |
| Identifier |   :ok: |     =      |   :ok:   | :ok: |  :x: |    :x:  |    :x:  |   :x: |    :x: |   :x: |    :x: |
| Variable   |   :ok: |   :ok:     |     =    | :ok: |  :x: |    :x:  |    :x:  |   :x: |    :x: |   :x: |    :x: |
| Arg        |   :ok: |   :ok:     |   :ok:   |   =  |  :x: |    :x:  |    :x:  |   :x: |    :x: |   :x: |    :x: |
| Path       |   :ok: |   :ok:     |    :x:   | :ok: |   =  |   :ok:  |   :ok:  |  :ok: |    :x: |   :x: |   :ok: |
| Integer    |   :ok: |    :x:     |    :x:   |  :x: |  :x: |     =   |   :ok:  |  :ok: |   :ok: |   :x: |   :ok: |
| Boolean    |   :ok: |   :ok:     |   :ok:   | :ok: | :ok: |   :ok:  |     =   |  :ok: |   :ok: |   :x: |   :ok: |
| Array      |   :ok: |   :ok:     |   :ok:   | :ok: | :ok: |   :ok:  |   :ok:  |    =  |   :ok: |  :ok: |    :x: |
| Object     |   :ok: |   :ok:     |   :ok:   | :ok: |  :x: |   :ok:  |   :ok:  |  :ok: |     =  |   :x: |   :ok: |
| Regex      |   :ok: |    :x:     |    :x:   |  :x: |  :x: |    :x:  |    :x:  |  :ok: |    :x: |    =  |    :x: |
| Stream     |   :ok: |    :x:     |    :x:   |  :x: |  :x: |   :ok:  |    :x:  |  :ok: |    :x: |   :x: |     =  |

As shown in the table, anything can be converted to/from a `String`, while `Regex` is much more selective. Here are some details about how casts are expected to work:

- A cast where the type is the same as the input will return the input itself as a copy.
- `String` to `Array` depends on the type of string. Multi-line strings are split into lines, and single-line strings are split by `IFS`.
- `Boolean` conversions should be intuitive, allowing for safe lazy evaluation of an undefined `Identifier`, returning `false` when a `Path` does not exist or when an `Array` (or other collection) is empty. All non-zero `Integer` values are `true`.
- Converting an `Array` into a `Regex` will yield a regular expression that can match any of the values in the collection.
- `Stream` and `Integer` are interchangeable since streams are an abstraction of numbered file descriptors.
- Attempting to cast an incompatible type will result in an error.

Casts are performed by using the type name as a function:

```
$path = Path("/usr/local/bin")
$str = String($path)
```

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

