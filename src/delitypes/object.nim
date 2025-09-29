import ./common

proc dKeys(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkObject
  let obj = arg

  result = DK(dkArray)
  for key in obj.table.keys:
    result.sons.add DKStr(key)

proc dLookup(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkObject
  let obj = arg
  nextarg dkIdentifier
  let id = arg.id
  return obj.table[id]

let ObjectFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "": dLookup,
  "keys": dKeys,
}.toTable
