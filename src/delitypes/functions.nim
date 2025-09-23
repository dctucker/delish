import std/tables
import ../deliast
import ./path
import ./integer

type DeliFunction = proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.}
type DeliFunctionTable = Table[string, DeliFunction]
type TypeFunctionTable = Table[DeliKind, DeliFunctionTable]

let TypeFunctions: TypeFunctionTable = {
  dkPath: PathFunctions,
  dkInteger: IntegerFunctions,
}.toTable

proc typeFunction*(kind: DeliKind, op: DeliNode): DeliFunction =
  assert op.kind == dkIdentifier
  TypeFunctions[kind][op.id]

proc typeFunctions*(kind: DeliKind): seq[string] =
  if kind in TypeFunctions:
    let funcs = TypeFunctions[kind]
    for key, v in funcs:
      result.add key
