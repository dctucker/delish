import std/strutils
import ../deliast

proc parseInteger*(str: string): int =
  if str.len > 2 and str[0..1] == "0x":
    result = parseHexInt(str)
  elif str.len > 1 and str[0] == '0':
    result = parseOctInt(str)
  else:
    result = parseInt(str)
  #stderr.write "parsed '", str, "'", " = ", result, "\n"

proc parseBoolean*(str: string): bool =
  return str == "true"

# 123.45
# 0.12345
# 12345.000
# max 64-bit uint: 18446744073709551616 (19 digits)
# max 32-bit  int: 4294967296            (9 digits)
proc parseDecimal*(str: string): Decimal =
  var parts = str.split('.')
  result.whole = parts[0].parseInt
  result.fraction = parts[1].parseInt
  result.decimals = parts[1].len

