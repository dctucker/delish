### Evaluation ###

proc isTruthy(engine: Engine, node: DeliNode): bool =
  case node.kind
  of dkBoolean: return node.boolVal
  else:
    return false

proc evalMath(engine: Engine, op, v1, v2: DeliNode): DeliNode =
  return case op.kind
  of dkAddOp: v1 + v2
  of dkSubOp: v1 - v2
  of dkMulOp: v1 * v2
  of dkDivOp: v1 / v2
  of dkModOp: v1 mod v2
  else:
    todo "evalMath " & $op
    deliNone()

proc evalComparison(engine: Engine, op, v1, v2: DeliNode): DeliNode =
  let val = case op.kind
  of dkEqOp: v1 == v2
  of dkNeOp: v1 != v2
  of dkGtOp: v1 >  v2
  of dkGeOp: v1 >= v2
  of dkLtOp: v1 <  v2
  of dkLeOp: v1 <= v2
  else:
    todo "evalComparison ", $op
    false
  return DeliNode(kind: dkBoolean, boolVal: val)

proc evalCondExpr(engine: Engine, op: DeliNode, v1: DeliNode, v2: DeliNode): DeliNode =
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

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind

  of dkBoolean, dkString, dkIdentifier, dkDecimal, dkInteger, dkPath,
     dkStrBlock, dkStrLiteral, dkJump, dkNone, dkRegex, dkCode:
    return val

  of dkLazy:
    return val.sons[0]

  of dkStream,
    dkEnvDefault,
    dkCondition,
    dkBoolExpr:
    return engine.evaluate( val.sons[0] )

  of dkStreamIn:  return DeliNode(kind: dkStream, intVal: 0)
  of dkStreamOut: return DeliNode(kind: dkStream, intVal: 1)
  of dkStreamErr: return DeliNode(kind: dkStream, intVal: 2)

  of dkArray:
    result = DeliNode(kind: dkArray)
    for son in val.sons:
      result.sons.add(engine.evaluate(son))
    return result

  of dkObject:
    result = DK( dkObject )
    for pair in val.sons:
      let str = engine.evalPairKey( pair.sons[0] )
      result.table[str] = engine.evaluate(pair.sons[1])
    #stderr.write printValue(result)
    return result

  of dkDateTime:
    let date = val.sons[0].sons
    let time = val.sons[1].sons
    result = DK( dkDateTime )
    result.dtVal = dateTime(
      date[0].intVal,
      Month(date[1].intVal),
      date[2].intVal,
      time[0].intVal,
      time[1].intVal,
      time[2].intVal,
    )
    return result

  of dkRunStmt:
    let ran = engine.doRun(val)
    return ran

  of dkExpr:
    return engine.evalExpression(val)

  of dkVariable:
    return engine.getVariable(val.varName)

  of dkVarDeref:
    return engine.evalVarDeref(val)

  of dkArg:
    debug 3:
      stdout.write "  dereference ", val.sons[0]
    let arg = engine.getArgument(val.sons[0])
    #if arg.isNone(): engine.runtimeError("Undeclared argument: " & val.sons[0].argName)
    result = engine.evaluate(arg)
    debug 3:
      stderr.write " = ", $result
    return result

  of dkArgExpr:
    let arg = val.sons[0]
    let aval = engine.evalExpression(val.sons[1])
    result = DK(dkArray, arg, aval)
    return result

  of dkOpenExpr:
    return engine.doOpen(val.sons)

  of dkBoolNot:
    return not engine.evaluate( val.sons[0] ).toBoolean()

  of dkCondExpr:
    let v1 = val.sons[1]
    let v2 = val.sons[2]
    return engine.evalCondExpr( val.sons[0], v1, v2 )

  of dkComparison:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalComparison(val.sons[0], v1, v2)

  of dkMathExpr:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalMath(val.sons[0], v1, v2)

  of dkFunctionCall:
    return engine.evalFunctionCall(val.sons[0], val.sons[1 .. ^1])

  of dkCast:
    return engine.evaluate(val.sons[1]).toKind(val.sons[0].kind)

  of dkElse:
    return deliTrue()

  else:
    todo "evaluate ", val.kind
    return deliNone()
