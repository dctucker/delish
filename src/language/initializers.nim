proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)

proc DK*(kind: DeliKind, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    sons.add(node)
  return DeliNode(kind: kind, sons: sons)

proc DKExpr*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExpr )
  for node in nodes:
    result.sons.add(node)

proc DKExprList*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExprList )
  for node in nodes:
    result.sons.add(node)


proc DKArg*(argName: string): DeliNode =
  if argName.len == 0:
    raise newException(ValueError, "empty argument name")
  if argName.len == 1:
    return DeliNode(kind: dkArgShort, argName: argName)
  return DeliNode(kind: dkArgLong, argName: argName)

proc DKId*(id: string): DeliNode =
  return DeliNode(kind: dkIdentifier, id: id)

proc DKVar*(varName: string): DeliNode =
  return DeliNode(kind: dkVariable, varName: varName)

proc DKVarStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkVariableStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKLocalStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkLocalStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKInt*(intVal: int): DeliNode =
  return DeliNode(kind: dkInteger, intVal: intVal)

proc DKDec*(decVal: Decimal): DeliNode =
  return DeliNode(kind: dkDecimal, decVal: decVal)

proc DKDecimal*(whole, fraction: int, decimals: int): DeliNode =
  return DeliNode(kind: dkDecimal, decVal: Decimal(whole: whole, fraction: fraction, decimals: decimals))

proc DKDateTime*(str: string): DeliNode =
  let strs = str.split({'T','t',' ','+','@'})
  let date = times.parse(strs[0], "yyyy-MM-dd")
  let time = times.parse(strs[1], "HH:mm:ss")
  let dtVal = dateTime(
    date.year, date.month, date.monthday,
    time.hour, time.minute, time.second
  )
  return DeliNode(kind: dkDateTime, dtVal: dtVal)

proc DKDateTime*(dtVal: DateTime): DeliNode =
  return DeliNode(kind: dkDateTime, dtVal: dtVal)

proc DKDateTime*(decVal: Decimal): DeliNode =
  result = DeliNode(kind: dkDateTime)
  result.dtVal = decVal.whole.fromUnix().local()
  {.warning[Deprecated]:off.}
  result.dtVal.nanosecond = decVal.fraction
  {.warning[Deprecated]:on.}

proc DKBool*(boolVal: bool): DeliNode =
  return DeliNode(kind: dkBoolean, boolVal: boolVal)

proc deliTrue* (): DeliNode = DKBool(true)
proc deliFalse*(): DeliNode = DKBool(false)

proc DKLazy*(node: DeliNode): DeliNode =
  return DeliNode(kind: dkLazy, sons: @[node])

proc DKNotNone*(node: DeliNode): DeliNode =
  return DeliNode(kind: dkBoolExpr, sons: @[
    node, DeliNode(kind: dkNeOp), deliNone()
  ])

proc DKStr*(strVal: string): DeliNode =
  return DeliNode(kind: dkString, strVal: strVal)

proc DKStream*(intVal: int): DeliNode =
  return DeliNode(kind: dkStream, intVal: intVal)

proc DKRan*(): DeliNode =
  return DeliNode(kind: dkRan, table: {
    "id": DeliNode(kind: dkNone),
    "in":  DeliNode(kind: dkNone),
    "out": DeliNode(kind: dkNone),
    "err": DeliNode(kind: dkNone),
    "exit": DeliNode(kind: dkNone),
  }.toTbl)

proc DKPath*(strVal: string): DeliNode =
  return DeliNode(kind: dkPath, strVal: strVal)

proc DKStmt*(kind: DeliKind, args: varargs[DeliNode]): DeliNode =
  return DK( dkStatement, DK( kind, args ) )

proc DKInner*(line: int, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    node.line = line
    sons.add(node)
  return DeliNode(kind: dkInner, sons: sons, line: line)

proc DKCallable*(fn: DeliFunction, sons: seq[DeliNode]): DeliNode =
  result = DeliNode(kind: dkCallable, function: fn, sons: sons)

proc DKType*(kind: DeliKind): DeliNode =
  result = DK( dkType, DK( kind ) )

let DKTrue*  = DeliNode(kind: dkBoolean, boolVal: true)
let DKFalse* = DeliNode(kind: dkBoolean, boolVal: false)

proc DeliObject*(table: openArray[tuple[key: string, val: DeliNode]]): DeliNode =
  return DeliNode(kind: dkObject, table: table.toTbl)
