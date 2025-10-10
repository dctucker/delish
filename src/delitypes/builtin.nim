import ./[common, parse]

proc dJson(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg {dkString, dkStrBlock, dkStrLiteral}
  maxarg
  return parseJsonString(arg.strVal)

let BuiltinFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "json": dJson,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkNone] = {
    "json": "Returns a JSON object of the parsed string",
  }.toTable
