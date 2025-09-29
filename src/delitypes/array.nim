import ./common
import ./string as str

proc dJoin(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkArray
  let sons = arg.sons

  var sep = DeliNode(kind: dkString, strVal: "")
  if arg_i < nodes.len:
    sep = nodes[arg_i]

  result = DKStr("")
  for son in sons:
    result.strVal &= son.asString.strVal & sep.strVal
  result.strVal = result.strVal[0..^(1 + sep.strVal.len)]

let ArrayFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "join": dJoin,
  "None": dNop,
}.toTable
