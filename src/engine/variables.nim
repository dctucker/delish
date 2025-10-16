### Variables ###

proc printVariables(engine: Engine) =
  debug 2:
    echo "\27[36m== Engine Variables (", engine.variables.len(), ") =="
    for k,v in engine.variables:
      stdout.write("  $", k, " = ")
      stdout.write(v.repr)
      stdout.write("\n")

proc getVariable*(engine: Engine, name: string): DeliNode =
  let locals = engine.locals.peekUnsafe
  if locals.contains(name):
    return locals[name]
  if engine.variables.contains(name):
    return engine.variables[name]
  elif engine.envars.contains(name):
    return DKStr(engine.envars[name])
  elif name == "@":
    # TODO
    return DK(dkArray)
  else:
    engine.runtimeError("Unknown variable: $" & name)

proc evalVarDeref(engine: Engine, vard: DeliNode): DeliNode =
  #echo "evalVarDeref ", vard.repr
  let variable = vard.sons[0]
  case variable.kind
  of dkVariable:
    result = engine.getVariable(variable.varName)
  of dkArray:
    result = variable
  else:
    todo "evalVarDeref ", variable.kind
  #echo result

  for son in vard.sons[1 .. ^1]:
    case result.kind
    of dkObject, dkRan:
      let str = son.toString()
      if str notin result.table:
        engine.runtimeError("$" & variable.varName & " does not contain \"" & str & "\"")
      result = result.table[str]
    of dkArray:
      if son.kind == dkIdentifier:
        if son.id in typeFunctions(dkArray):
          result = typeFunction(result.kind, son)(result)
        else:
          engine.runtimeError("Unknown array function: " & son.id)
        continue
      #echo engine.evaluate(son.repr).repr
      engine.printLocals()
      let idx = engine.evaluate(son).intVal
      if idx < result.sons.len:
        result = result.sons[idx]
      else:
        result = deliNone()
    of dkString,
       dkInteger,
       dkDecimal,
       dkDateTime,
       dkPath:
      if son.kind == dkIdentifier:
        # TODO this shouldn't execute the function, it should turn it into a function call
        #result = DKCallable(typeFunction(result.kind, son), @[result])
        result = typeFunction(result.kind, son)(result)
      else:
        result = deliNone()
      if result.kind == dkNone:
        todo "evalVarDeref ", result.kind, " using ", $son
    else:
      todo "evalVarDeref ", result.kind, " using ", son.kind

proc assignVariable(engine: Engine, key: string, value: DeliNode) =
  debug 3:
    stdout.write "  "
  if engine.locals.peekUnsafe.contains(key):
    engine.assignLocal(key, value)
    debug 3:
      stdout.write "local "
  elif engine.envars.contains(key):
    engine.assignEnvar(key, value.toString())
    engine.variables[key] = value
  else:
    engine.variables[key] = value
  debug 3:
    echo "$", key, " = ", $value

proc varAssignLazy(engine: Engine, key: DeliNode, op: DeliNode, value: DeliNode) =
  if value.kind == dkLazy:
    engine.insertStmt( DKInner(engine.current.line,
       DK( dkVariableStmt, key, op, value.sons[0])
    ))
  else:
    engine.assignVariable(key.varName, value)

proc doDerefAssign(engine: Engine, into: DeliNode, op: DeliNode, expr: DeliNode) =
  let val = if expr.kind == dkExpr:
      expr.sons[0]
    else:
      expr
  case op.kind
  of dkAssignOp:
    let key = into.sons[0].varName
    var index = into.sons[1]
    if index.kind == dkVariable:
      index = engine.evaluate(index)
    let value = engine.evaluate(val)
    engine.getVariable(key).sons[index.intVal] = value
  else:
    todo "doDerefAssign ", op.kind

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, expr: DeliNode) =
  let val = if expr.kind == dkExpr:
      expr.sons[0]
    else:
      expr
  case op.kind
  of dkAssignOp:
    let value = engine.evaluate(val)
    engine.varAssignLazy(key, op, value)
    debug 3:
      echo key, " = " & value.repr
  of dkAppendOp:
    let variable = engine.getVariable(key.varName)
    let value = case val.kind
      of dkVarDeref:
        engine.evalVarDeref(val)
      of dkFunctionCall:
        engine.evaluate(val)
      else:
        val
    debug 3:
      echo variable, " += ", value.repr
    if variable.kind in dkIntegerKinds:
      let eval = engine.evaluate(DK(dkMathExpr, dkAddOp, variable, value))
      engine.varAssignLazy(key, op, eval)
    else:
      engine.varAssignLazy(key, op, variable + value)
  of dkRemoveOp:
    let variable = engine.getVariable(key.varName)
    let value = if val.kind == dkVarDeref:
      engine.evalVarDeref(val)
    else:
      val
    debug 3:
      echo variable, " -= ", value.repr
    let out_value = variable - value
    engine.assignVariable(key.varName, out_value)
  else:
    todo "assign ", op.kind
