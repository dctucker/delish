converter toDeliNode*(kind: DeliKind): DeliNode {.inline.} =
  return DeliNode(kind: kind)

proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)

proc addSon*(parent: DeliNode, node: DeliNode) =
  node.parent = parent
  #if node.parents.len == 0:
  #  node.parents.add parent
  parent.sons.add(node)

proc addSons*(parent: DeliNode, nodes: varargs[DeliNode]) =
  for node in nodes:
    parent.addSon node

proc DK*(kind: DeliKind, nodes: varargs[DeliNode]): DeliNode =
  result = DeliNode(kind: kind)
  result.addSons nodes

proc DKArray*(nodes: varargs[DeliNode]): DeliValue =
  result = DeliNode(kind: dkArray)
  result.addSons nodes

proc DKExpr*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExpr )
  result.addSons nodes

proc DKExprList*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExprList )
  result.addSons nodes

proc DKArgShort*(argName: string): DeliValue =
  return DeliValue(kind: dkArgShort, argName: argName)

proc DKArgLong*(argName: string): DeliValue =
  return DeliValue(kind: dkArgLong, argName: argName)

proc DKArg*(argName: string): DeliValue =
  if argName.len == 0:
    raise newException(ValueError, "empty argument name")
  if argName.len == 1:
    return DKArgShort(argName)
  return DKArgLong(argName)

proc DKId*(id: string): DeliValue =
  return DeliValue(kind: dkIdentifier, id: id)

proc DKVar*(varName: string): DeliValue =
  return DeliValue(kind: dkVariable, varName: varName)

proc DKVarStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkVariableStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKLocalStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkLocalStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKInt*(intVal: int): DeliValue =
  return DeliValue(kind: dkInteger, intVal: intVal)
proc DKInt8*(intVal: int): DeliValue =
  return DeliValue(kind: dkInt8, intVal: intVal)
proc DKInt10*(intVal: int): DeliValue =
  return DeliValue(kind: dkInt10, intVal: intVal)
proc DKInt16*(intVal: int): DeliValue =
  return DeliValue(kind: dkInt16, intVal: intVal)

proc DKError*(intVal: int): DeliValue =
  return DeliValue(kind: dkError, intVal: intVal)

proc DKDec*(decVal: Decimal): DeliValue =
  return DeliValue(kind: dkDecimal, decVal: decVal)

proc DKDecimal*(whole, fraction: int, decimals: int): DeliValue =
  return DeliValue(kind: dkDecimal, decVal: Decimal(whole: whole, fraction: fraction, decimals: decimals))

proc DKDateTime*(str: string): DeliValue =
  let strs = str.split({'T','t',' ','+','@'})
  let date = times.parse(strs[0], "yyyy-MM-dd")
  let time = times.parse(strs[1], "HH:mm:ss")
  let dtVal = dateTime(
    date.year, date.month, date.monthday,
    time.hour, time.minute, time.second
  )
  return DeliValue(kind: dkDateTime, dtVal: dtVal)

proc DKDateTime*(dtVal: DateTime): DeliValue =
  return DeliValue(kind: dkDateTime, dtVal: dtVal)

proc DKDateTime*(decVal: Decimal): DeliValue =
  result = DeliValue(kind: dkDateTime)
  result.dtVal = decVal.whole.fromUnix().local()
  {.warning[Deprecated]:off.}
  result.dtVal.nanosecond = decVal.fraction
  {.warning[Deprecated]:on.}

proc DKBool*(boolVal: bool): DeliValue =
  return DeliValue(kind: dkBoolean, boolVal: boolVal)

proc deliTrue* (): DeliValue = DKBool(true)
proc deliFalse*(): DeliValue = DKBool(false)

proc DKLazy*(node: DeliNode): DeliNode =
  return DeliNode(kind: dkLazy, sons: @[node])

proc DKNotNone*(node: DeliNode): DeliNode =
  result = DK(dkBoolExpr, node, DK(dkNeOp), deliNone())

proc DKStr*(strVal: string): DeliValue =
  return DeliValue(kind: dkString, strVal: strVal)

proc DKStream*(intVal: int, args: varargs[DeliValue]): DeliValue =
  result = DeliValue(kind: dkStream, intVal: intVal)
  result.addSons args

proc DKOut*(): DeliNode = DKStream(0, DK(dkStreamOut))

proc DKRan*(): DeliValue =
  return DeliValue(kind: dkRan, table: {
    "id": DeliValue(kind: dkNone),
    "in":  DeliValue(kind: dkNone),
    "out": DeliValue(kind: dkNone),
    "err": DeliValue(kind: dkNone),
    "exit": DeliValue(kind: dkNone),
  }.toTbl)

proc DKPath*(strVal: string): DeliValue =
  return DeliValue(kind: dkPath, strVal: strVal)

proc DKStmt*(kind: DeliKind, args: varargs[DeliNode]): DeliNode =
  return DK( dkStatement, DK( kind, args ) )

proc DKInner*(line: int, nodes: varargs[DeliNode]): DeliNode =
  result = dkInner
  result.line = line
  result.addSons nodes
  for son in result.sons:
    son.line = line

proc DKJump*(line: int): DeliNode =
  result = DeliNode(kind: dkJump)
  result.line = line

proc DKJump*(list_node: DeliListNode): DeliNode =
  result = DeliNode(kind: dkJump)
  result.list_node = list_node

proc DKBreak*(line: int): DeliNode =
  result = DeliNode(kind: dkBreakStmt)
  result.line = line

proc DKContinue*(line: int): DeliNode =
  result = DeliNode(kind: dkContinueStmt)
  result.line = line

proc DKCallable*(fn: DeliFunction, sons: seq[DeliNode]): DeliNode =
  result = DeliNode(kind: dkCallable, function: fn, sons: sons)

proc DKType*(kind: DeliKind): DeliNode =
  result = DK( dkType, DK( kind ) )

proc DKIter*(gen: DeliGenerator): DeliNode =
  return DeliNode(kind: dkIterable, generator: gen)

let DKTrue*  = DeliValue(kind: dkBoolean, boolVal: true)
let DKFalse* = DeliValue(kind: dkBoolean, boolVal: false)

proc DKObject*(table: DeliTable): DeliValue =
  return DeliValue(kind: dkObject, table: table)

proc DKRegex*(pattern: string): DeliValue =
  return DeliValue(kind: dkRegex, pattern: pattern)

proc DeliObject*(table: openArray[tuple[key: string, val: DeliValue]]): DeliValue =
  return DeliValue(kind: dkObject, table: table.toTbl)

proc DKNone*(): DeliValue =
  return dkNone
