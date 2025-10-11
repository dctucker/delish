| Built-in |   |
|----------|---|
| `json`        | Returns a JSON object of the parsed string |

| Array |   |
|----------|---|
| `.join`       | Returns a string of the array joined by the specified separator. |
| `.map`        | Calls a function for each item in the array. |
| `.seq`        | Generates integers in sequence. |
| `.iter`       | Generates a value for each item in the array. |

| Object |   |
|----------|---|
| `.json`       | Returns a JSON string representing the object |
| `.iter`       | Generates a string for each of the object's keys |
| `.keys`       | Returns an array of strings representing the object's keys |

| String |   |
|----------|---|
| `.split`      | Returns an array of strings by splitting the string by space or the specified delimiter |
| `.iter`       | Generates a string after splitting the string by space |

| Decimal |   |
|----------|---|
| `.frac`       | Returns an integer of the fractional numerator. |
| `.denominator` | Returns an integer of the fractional denominator. |
| `.exponent`   | Returns the integer number of fractional significant digits. |

| DateTime |   |
|----------|---|
| `.year`       | Returns an integer year. |
| `.now`        | Returns the current date and time. |
| `.month`      | Returns an integer month (1-12). |
| `.minute`     | Returns an integer minute (0-59). |
| `.nanosecond` | Returns an integer nanosecond (0-999999999). |
| `.second`     | Returns an integer second (0-59). |
| `.day`        | Returns an integer day (1-31). |
| `.hour`       | Returns an integer hour (0-23). |

| Integer |   |
|----------|---|
| `.oct`        | Returns an octal integer (base 8) |
| `.dec`        | Returns a decimal integer (base 10) |
| `.hex`        | Returns a hexadcimal integer (base 16) |

| Path |   |
|----------|---|
| `.pwd`        | Returns the path of the working directory. |
| `.chmod`      | Change the specified path's mode. |
| `.basename`   | Returns the file portion of the path. |
| `.iter`       | Generates each path in the specified directory. |
| `.dirname`    | Returns the directory portion of the path. |
| `.test`       | Evaluates a condition on the path. |
| `.list`       | Returns an array of paths in the specified directory. |
| `.chdir`      | Change the working directory. |
| `.stat`       | Returns an object representing the path's status. Also supports `stat`. |
| `.mkdir`      | Make a directory. Use `-p` to create all parent directories. |
| `.home`       | Returns the path of the current user's home directory. |
