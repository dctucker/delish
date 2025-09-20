import std/tables
import ../deliast
import path

type DeliFunction = proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.}
type DeliFunctionTable = Table[string, DeliFunction]
type TypeFunctionTable = Table[DeliKind, DeliFunctionTable]

let TypeFunctions: TypeFunctionTable = {
  dkPath: PathFunctions,
}.toTable

proc typeFunction*(kind: DeliKind, op: DeliNode): DeliFunction =
  assert op.kind == dkIdentifier
  TypeFunctions[kind][op.id]
