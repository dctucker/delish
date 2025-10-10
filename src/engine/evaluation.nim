### Evaluation ###

proc remakeInt(node: var DeliNode, kind: DeliKind) =
  if node.kind in dkIntegerKinds and kind in dkIntegerKinds:
    {.push warning[CaseTransition]: off.}
    node.kind = kind
    {.pop.}

proc isTruthy(engine: Engine, node: DeliNode): bool =
  case node.kind
  of dkBoolean: return node.boolVal
  else:
    return false

proc evalMath(engine: Engine, op, v1, v2: DeliNode): DeliNode {.inline.} =
  var a = engine.evaluate(v1)
  var b = engine.evaluate(v2)
  if {a.kind, b.kind} == {dkInteger, dkDecimal}:
    a = a.toKind(dkDecimal)
    b = b.toKind(dkDecimal)

  var final_kind = a.kind
  if a.kind in dkIntegerKinds and b.kind in dkIntegerKinds:
    a = DKInt(a.intVal)
    b = DKInt(b.intVal)

  result = case op.kind
  of dkAddOp  : a  +   b
  of dkSubOp  : a  -   b
  of dkMulOp  : a  *   b
  of dkDivOp  : a  /   b
  of dkModOp  : a mod  b
  of dkBitOr  : a or   b
  of dkBitAnd : a and  b
  of dkBitXor : a xor  b
  of dkBitNor : a.nor  b
  of dkBitNand: a.nand b
  of dkBitXnor: a.xnor b
  of dkBitShl : a shl  b
  of dkBitShr : a shr  b
  else:
    todo "evalMath " & $op
    deliNone()

  result.remakeInt(final_kind)

proc evalBitNot(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  let v = engine.evaluate( val )
  result = not v.toInteger()
  result.remakeInt v.kind
  return result


proc evalComparison(engine: Engine, op, v1, v2: DeliNode): DeliNode {.inline.} =
  let a = engine.evaluate(v1)
  let b = engine.evaluate(v2)
  let val = case op.kind
  of dkEqOp: a == b
  of dkNeOp: a != b
  of dkGtOp: a >  b
  of dkGeOp: a >= b
  of dkLtOp: a <  b
  of dkLeOp: a <= b
  else:
    todo "evalComparison ", $op
    false
  return DeliNode(kind: dkBoolean, boolVal: val)

proc evalCondExpr(engine: Engine, op: DeliNode, v1: DeliNode, v2: DeliNode): DeliNode {.inline.} =
  case op.kind
  of dkBoolAnd:
    let v1 = engine.evaluate(v1).toBoolean()
    if v1.boolVal == false:
      return v1
    return engine.evaluate(v2).toBoolean()
  of dkBoolOr:
    let v1 = engine.evaluate(v1).toBoolean()
    if v1.boolVal == true:
      return v1
    return engine.evaluate(v2).toBoolean()
  of dkBoolNand:
    let v1 = not engine.evaluate(v1).toBoolean()
    if v1.boolVal == true:
      return v1
    return not engine.evaluate(v2).toBoolean()
  of dkBoolNor:
    let v1 = not engine.evaluate(v1).toBoolean()
    if v1.boolVal == false:
      return v1
    return not engine.evaluate(v2).toBoolean()
  else:
    todo "evalCondExpr ", op.kind

proc evalExpression(engine: Engine, expr: DeliNode): DeliNode =
  result = expr
  while result.kind == dkExpr:
    let s = result.sons[0]
    #stderr.write s.kind
    result = engine.evaluate(s)

proc evaluateStream(engine: Engine, stream: DeliNode): FileDesc =
  #let num = if stream.sons.len() > 0:
  #  engine.variables[stream.sons[0].varName].intVal
  #else:
  #  stream.intVal
  let num = engine.evaluate(stream).getStreamNumber()
  if engine.fds.contains(num):
    return engine.fds[num]

proc evalPairKey(engine: Engine, k: DeliNode): string =
  case k.kind
  of dkString:     k.strVal
  of dkIdentifier: k.id
  of dkExpr:       engine.evalPairKey( engine.evaluate(k) )
  else:
    todo "evaluate Object with key ", k.kind
    ""

proc evalArray(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  result = DeliNode(kind: dkArray)
  for son in val.sons:
    result.addSon engine.evaluate(son)

proc evalObject(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  result = DK( dkObject )
  for pair in val.sons:
    let str = engine.evalPairKey( pair.sons[0] )
    result.table[str] = engine.evaluate(pair.sons[1])

proc evalJsonBlock(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  result = val.sons[0].strVal.parseJsonString
  if result.kind == dkError:
    raise newException(RuntimeError, "Error parsing JSON")

proc evalDateTime(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  let date = val.sons[0].sons
  let time = val.sons[1].sons
  result = DK( dkDateTime )
  result.dtVal = dateTime(
    date[0].intVal,
    date[1].intVal.Month,
    date[2].intVal,
    time[0].intVal,
    time[1].intVal,
    time[2].intVal,
  )

proc evalVariable(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  result = engine.getVariable(val.varName)
  if result.kind == dkIterable:
    result = engine.evaluate(result)
  return result

proc evalArg(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  debug 3:
    stdout.write "  dereference ", val.sons[0]
  let arg = engine.getArgument(val.sons[0])
  #if arg.isNone(): engine.runtimeError("Undeclared argument: " & val.sons[0].argName)
  result = engine.evaluate(arg)
  debug 3:
    stderr.write " = ", $result
  return result

proc evalArgExpr(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  let arg = val.sons[0]
  let aval = engine.evalExpression(val.sons[1])
  result = DK(dkArray, arg, aval)
  return result

proc evalIterable(engine: Engine, val: DeliNode): DeliNode {.inline.} =
  result = val.generator()
  if finished(val.generator):
    result = deliNone()

proc evaluate*(engine: Engine, val: DeliNode): DeliNode =
  case val.kind

  of dkBoolean,
     dkString,
     dkIdentifier,
     dkDecimal,
     dkInteger,
     dkPath,
     dkInt10,
     dkInt8,
     dkInt16,
     dkStrBlock,
     dkStrLiteral,
     dkJump,
     dkNone,
     dkRegex,
     dkCode:      return val

  of dkLazy:      return val.sons[0]

  of dkStream,
    dkEnvDefault,
    dkCondition,
    dkBoolExpr:   return engine.evaluate( val.sons[0] )

  of dkStreamIn:     return DKStream(0)
  of dkStreamOut:    return DKStream(1)
  of dkStreamErr:    return DKStream(2)

  of dkArray:        return engine.evalArray(val)
  of dkObject:       return engine.evalObject(val)
  of dkJsonBlock:    return engine.evalJsonBlock(val)
  of dkDateTime:     return engine.evalDateTime(val)
  of dkRunStmt:      return engine.doRun(val)
  of dkExpr:         return engine.evalExpression(val)
  of dkVariable:     return engine.evalVariable(val)
  of dkVarDeref:     return engine.evalVarDeref(val)
  of dkArg:          return engine.evalArg(val)
  of dkArgExpr:      return engine.evalArgExpr(val)
  of dkOpenExpr:     return engine.doOpen(val.sons)
  of dkBoolNot:      return not engine.evaluate(val.sons[0]).toBoolean()
  of dkCondExpr:     return engine.evalCondExpr(val.sons[0], val.sons[1], val.sons[2])
  of dkComparison:   return engine.evalComparison(val.sons[0], val.sons[1], val.sons[2])
  of dkMathExpr:     return engine.evalMath(val.sons[0], val.sons[1], val.sons[2])
  of dkBitNot:       return engine.evalBitNot(val.sons[0])
  of dkFunctionCall: return engine.evalFunctionCall(val.sons[0], val.sons[1 .. ^1])
  of dkCast:         return engine.evaluate(val.sons[1]).toKind(val.sons[0].kind)
  of dkIterable:     return engine.evalIterable(val)
  of dkElse:         return deliTrue()

  else:
    todo "evaluate ", val.kind
    return deliNone()
