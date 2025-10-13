import ./common
import ./string as str

proc dJoin(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkArray
  let sons = arg.sons

  var sep = DKStr("")
  if arg_i < nodes.len:
    sep = nodes[arg_i]

  result = DKStr("")
  for son in sons:
    result.strVal &= son.asString.strVal & sep.strVal
  result.strVal = result.strVal[0..^(1 + sep.strVal.len)]

proc gSeq(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkIntegerKinds
  var val2 = arg.intVal

  nextopt DKInt(1)
  var val1 = arg.intVal

  if val1 != 1:
    let t = val2
    val2 = val1
    val1 = t

  iterator gen(): DeliNode =
    for i in val1..val2:
      yield DKInt(i)
  return DKIter(gen)

proc gIter(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkArray
  maxarg

  iterator gen(): DeliNode =
    for son in arg.sons:
      yield son
  return DKIter(gen)

proc dSeq(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkIntegerKinds
  var val2 = arg.intVal

  nextopt DKInt(1)
  var val1 = arg.intVal

  if val1 != 1:
    let t = val2
    val2 = val1
    val1 = t

  result = dkArray
  for i in val1..val2:
    result.addSon DKInt(i)

proc dMap(nodes: varargs[DeliNode]): DeliNode =
  argvars

  nextArg dkArray
  let sons = arg.sons

  shift
  let fn = arg

  result = dkArray
  for son in sons:
    result.addSon DK(dkFunctionCall, DK(dkCallable, fn), son)

let ArrayFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "seq": gSeq,
  "join": dJoin,
  "map": dMap,
  "iter": gIter,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkArray] = {
    "seq": "Generates integers in sequence.",
    "join": "Returns a string of the array joined by the specified separator.",
    "map": "Calls a function for each item in the array.",
    "iter": "Generates a value for each item in the array.",
  }.toTable
