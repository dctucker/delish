import std/tables
import ./[
  common,
  path,
  integer,
  array,
  object,
  string as str,
  decimal,
  datetime,
]

type DeliFunctionTable = Table[string, DeliFunction]
type TypeFunctionTable = Table[DeliKind, DeliFunctionTable]

let TypeFunctions: TypeFunctionTable = {
  dkArray: ArrayFunctions,
  dkObject: ObjectFunctions,
  dkPath: PathFunctions,
  dkInteger: IntegerFunctions,
  dkInt10: IntegerFunctions,
  dkInt16: IntegerFunctions,
  dkInt8: IntegerFunctions,
  dkString: StringFunctions,
  dkDecimal: DecimalFunctions,
  dkDateTime: DateTimeFunctions,
}.toTable

proc typeFunction*(kind: DeliKind, op: DeliNode): DeliFunction =
  assert op.kind == dkIdentifier
  TypeFunctions[kind][op.id]

proc typeFunctions*(kind: DeliKind): seq[string] =
  if kind in TypeFunctions:
    let funcs = TypeFunctions[kind]
    for key, v in funcs:
      result.add key
