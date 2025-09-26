### Functions ###

proc reduceExprs(engine: Engine, args: seq[DeliNode]): seq[DeliNode] =
  for i in 0..args.len - 1:
    var arg = args[i]
    if arg.kind == dkExpr:
      arg = arg.sons[0]
    if arg.kind == dkArg and arg.sons.len > 0:
      arg = arg.sons[0]
    result.add arg

proc evalTypeFunction(engine: Engine, ty: DeliKind, fun: DeliNode, args: seq[DeliNode]): DeliNode =
  assert fun.kind == dkIdentifier
  let nextArgs = engine.reduceExprs(args)
  try:
    let fn = typeFunction(ty, fun)
    return fn(nextArgs)
  except ValueError as e:
    engine.runtimeError(e.msg)
  except KeyError as e:
    engine.runtimeError("Unknown function: ", $ty, ".", $fun.id)

proc evalDerefFunction(engine: Engine, variable: DeliNode, args: seq[DeliNode]): DeliNode =
  result = deliNone()
  if args[0].kind == dkIdentifier:
    let ty = variable.kind
    if args[0].id in typeFunctions(ty):
      var nextArgs = @[variable]
      for arg in args[1..^1]:
        nextArgs.add arg
      return engine.evalTypeFunction(ty, args[0], nextArgs)

proc evalFunctionCall(engine: Engine, fun: DeliNode, args: seq[DeliNode]): DeliNode =
  result = DK( dkLazy, DKVar(".returned") )
  var code: DeliNode

  case fun.kind
  of dkIdentifier:
    if fun.id notin engine.functions:
      engine.runtimeError("Unknown function: " & fun.id)
      #echo "Unknown function"
      #return DKInner(0, deliNone())
    code = engine.functions[fun.id]
  of dkVarDeref:
    code = engine.evaluate(fun)
    if code.kind != dkCode:
      return engine.evalDerefFunction(code, args)
  of dkType:
    return engine.evalTypeFunction(fun.sons[0].kind, args[0], args[1..^1])
  else:
    todo "evalFunctionCall ", fun

  var jump_return = DeliNode(kind: dkJump, line: -code.sons[0].line + 1)

  engine.setupPush( -code.sons[0].line + 1, {
    ".return": jump_return,
    ".args"  : DeliNode(kind: dkArray, sons: args),
    ".revtal": result,
  }.toTable)

  for s in code.sons:
    engine.insertStmt(s)

  let end_line = -code.sons[^1].line - 1
  jump_return.list_node = engine.writehead
  engine.setupPop(end_line)

  engine.debugNext()

proc doFunctionDef(engine: Engine, id: DeliNode, code: DeliNode) =
  if id.id in engine.functions:
    return
  engine.functions[id.id] = code
  debug 3:
    echo "define ", engine.functions

proc doFunctionDefs(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkFunctionDef:
    engine.doStmt(node)
  else:
    for son in node.sons:
      engine.doFunctionDefs(son)

proc checkFunctionCalls(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkFunctionStmt:
    let args = node.sons[0].sons
    case args[0].kind
    of dkIdentifier:
      let id = args[0].id
      if id notin engine.functions:
        engine.setupError("Unknown function: \"" & id & "\" at " & node.script.filename & ":" & $node.line)
    of dkType:
      let deliType = args[0].sons[0].kind
      let id = args[1].id
      if id notin typeFunctions(deliType):
        engine.setupError("Unknown function: \"" & $deliType & "." & id & "\" at " & node.script.filename & ":" & $node.line)
    of dkVarDeref:
      # TODO needs more static analysis
      discard
    else:
      engine.setupError("Invalid function call: " & $args)
  else:
    for son in node.sons:
      engine.checkFunctionCalls(son)

proc initFunctions(engine: Engine, script: DeliNode) =
  engine.doFunctionDefs(script)
  engine.checkFunctionCalls(script)
