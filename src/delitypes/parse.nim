import strutils

proc parse*(str: string): int =
  if str.len > 2 and str[0..1] == "0x":
    result = parseHexInt(str)
  elif str.len > 1 and str[0] == '0':
    result = parseOctInt(str)
  else:
    result = parseInt(str)
  #stderr.write "parsed '", str, "'", " = ", result, "\n"
