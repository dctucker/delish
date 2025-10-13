import
  std/[
    strutils,
    json,
  ],
  ./common,
  ../[
    errnos,
    signals,
  ]

proc parseError*(str: string): int =
  return parseEnum[PosixError](str, PosixError.ERROR).int

proc parseSignal*(str: string): int =
  return parseEnum[PosixSignal](str, PosixSignal.SIGNAL).int

proc parseNanoSecond*(str: string): int =
  result = parseInt(str.alignLeft(9, '0'))

proc parseInt10*(str: string): int =
  result = parseInt(str)

proc parseInteger*(str: string): int =
  if str.len > 2 and str[0..1] == "0x":
    result = parseHexInt(str)
  elif str.len > 1 and str[0] == '0':
    result = parseOctInt(str)
  else:
    result = parseInt10(str)
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

proc parseString*(str: string): string =
  result = str

proc assembleJson(node: JsonNode): DeliValue =
  case node.kind
  of JString:
    return DKStr(node.str)
  of JInt:
    return DKInt(node.num)
  of JFloat:
    return deliNone() # TODO
  of JBool:
    return DKBool(node.bval)
  of JNull:
    return deliNone()
  of JObject:
    result = DeliValue(kind: dkObject)
    for field,obj in node.fields.pairs:
      var js = assembleJson(obj)
      result.table[field] = js
  of JArray:
    result = DeliValue(kind: dkArray)
    for elem in node.elems:
      result.values.add assembleJson(elem)

proc parseJsonString*(str: string): DeliValue =
  try:
    let js = parseJson(str)
    return assembleJson(js)
  except JsonParsingError as e:
    return DKError(0)
