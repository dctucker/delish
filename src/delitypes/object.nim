import ./common

proc dKeys(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkObject
  let obj = arg

  result = DK(dkArray)
  for key in obj.table.keys:
    result.sons.add DKStr(key)

let ObjectFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "keys": dKeys,
}.toTable

