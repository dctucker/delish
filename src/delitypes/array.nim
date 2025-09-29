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

proc dSeq(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkInteger
  var val2 = arg.intVal

  nextopt DKInt(1)
  var val1 = arg.intVal

  if val1 != 1:
    let t = val2
    val2 = val1
    val1 = t

  result = DeliNode(kind: dkArray)
  for i in val1..val2:
    result.sons.add DKInt(i)

let ArrayFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "seq": dSeq,
  "join": dJoin,
  "None": dNop,
}.toTable
