import ./common

let ArrayFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "": dNop,
}.toTable
