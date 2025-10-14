import ./[common, parse]

proc dJson(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextarg {dkString, dkStrBlock, dkStrLiteral}
  maxarg
  return parseJsonString(arg.strVal)

let BuiltinFunctions*: Table[string, proc(nodes: varargs[DeliValue]): DeliValue {.nimcall.} ] = {
  "json": dJson,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkNone] = {
    "json": "Returns a JSON object of the parsed string",
  }.toTable
