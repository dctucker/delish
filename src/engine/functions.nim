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

proc evalValueFunction(engine: Engine, value, id: DeliNode, args: seq[DeliNode]): DeliNode =
  assert id.kind == dkIdentifier
  result = deliNone()
  let ty = value.kind
  if id.id in typeFunctions(ty):
    var nextArgs = @[value]
    for arg in args:
      nextArgs.add arg
    return engine.evalTypeFunction(ty, id, nextArgs)
  engine.runtimeError("Unknown function: ", $ty, ".", $id.id)


proc evalDerefFunction(engine: Engine, variable: DeliNode, args: seq[DeliNode]): DeliNode =
  result = deliNone()
  if args[0].kind == dkIdentifier:
    var nextArgs = @[variable]
    for arg in args[1..^1]:
      nextArgs.add arg
    return engine.evalValueFunction(variable, args[0], nextArgs)


proc evalIdentifierCall(engine: Engine, fun: DeliNode, args: seq[DeliNode]): DeliNode =
  result = DK( dkLazy, DKVar(".returned") )
  var code: DeliNode

  if fun.id notin engine.functions:
    engine.runtimeError("Unknown function: " & fun.id)
  code = engine.functions[fun.id]

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

proc setupCallCode(engine: Engine, code: DeliNode, args: seq[DeliNode]): DeliNode =
  result = DK( dkLazy, DKVar(".returned") )
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

proc varFunctionCall(v: DeliNode, id: DeliNode): DeliNode =
  return DK(dkFunctionCall, DK(dkCallable, DKType(v.kind), id), v)


# Callable( Identifier:hello )                               -> evaluate
# Callable( VarDeref:lib Identifier:validate )               -> FunctionCall( Callable( Type(VarDeref), validate ) VarDeref(lib) )
# Callable( Type(Path) Identifier:pwd )                      -> Callable( function:typeFunction(Path, "pwd") )
# Callable(
#   FunctionCall( Callable( Type( Path ) Identifier:pwd ) )
#   Identifier:list
# )                                                          -> FunctionCall( Callable( Type(Path) Identifier:list evaluate(Path.pwd) ) )
proc evalCallable(engine: Engine, callable: DeliNode): DeliNode =
  if callable.sons.len == 0:
    todo "evalCallable zero"
  let c0 = callable.sons[0]
  if callable.sons.len == 1:
    return c0

  let id = callable.sons[1]

  case c0.kind
  of dkCallable:
    todo "evalCallable " & $c0.sons
    #return engine.evalCallable(c0)
  of dkFunctionCall:
    result = DeliNode(kind: dkCallable)
    result.sons.add engine.evaluate(c0)
    for i in 1..(callable.sons.len - 1):
      result.sons.add callable.sons[i]
    return result
  of dkType:
    let ty = c0.sons[0].kind

    try:
      let function = typeFunction(ty, id)

      var extra: seq[DeliNode]
      for i in 2..(callable.sons.len - 1):
        extra.add callable.sons[i]

      return DKCallable(function, extra)

    except KeyError as e:
      engine.runtimeError("Unknown function: ", $ty, ".", id.id)
  of dkVarDeref:
    let deref = engine.evaluate(c0)
    if deref.kind != dkCode:
      return varFunctionCall(deref, id)
  else:
    if c0.kind in dkTypeKinds:
      return DK(dkFunctionCall, DK(dkCallable, DKType(c0.kind), id), c0)
  #of dkIdentifier:
  #  return DKCallable(setupCallCode, fn.sons[1..^1])
  ##of dkVarDeref:

  todo "evalCallable " & $c0.kind
  return deliNone()

    #return engine.evalTypeFunction(fun.sons[0].kind, args[0], args[1..^1])

proc evalFunctionCall(engine: Engine, callable: DeliNode, args: seq[DeliNode]): DeliNode =
  var c = callable
  while c.kind == dkCallable and c.function == nil:
    c = engine.evalCallable(c)
    debug 1:
      echo "evalCallback returned ", c.repr

  case c.kind
  of dkFunctionCall:
    for arg in args:
      c.sons.add arg
    return engine.evaluate(c)
  of dkIdentifier:
    return engine.evalIdentifierCall(c, args)
  #of dkVarDeref:
  #  code = engine.evaluate(fun)
  #  if code.kind != dkCode:
  #    return engine.evalDerefFunction(code, args)
  #of dkType:
  #  return engine.evalTypeFunction(fun.sons[0].kind, args[0], args[1..^1])
  #else:
  #  todo "evalFunctionCall ", fun
  of dkCallable:
    var next = c
    var value: DeliNode
    var nextArgs: seq[DeliNode]
    for arg in args:
      nextArgs.add arg
    if next.sons.len > 0:
      value = next.function()
      return engine.evalValueFunction(value, next.sons[0], nextArgs)
    else:
      echo "calling ", next, " with args ", nextArgs
      return next.function(nextArgs)
  else: discard

  todo "evalFunctionCall " & $c.kind
  return deliNone()


# TODO skip this for now
#proc checkFunctionCalls(engine: Engine, node: DeliNode) =
#  case node.kind:
#  of dkFunctionStmt:
#    let args = node.sons[0].sons
#    case args[0].kind
#    of dkIdentifier:
#      let id = args[0].id
#      if id notin engine.functions:
#        engine.setupError("Unknown function: \"" & id & "\" at " & node.script.filename & ":" & $node.line)
#    of dkType:
#      let deliType = args[0].sons[0].kind
#      let id = args[1].id
#      if id notin typeFunctions(deliType):
#        engine.setupError("Unknown function: \"" & $deliType & "." & id & "\" at " & node.script.filename & ":" & $node.line)
#    of dkVarDeref:
#      # TODO needs more static analysis
#      discard
#    else:
#      engine.setupError("Invalid function call: " & $args)
#  else:
#    for son in node.sons:
#      engine.checkFunctionCalls(son)

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

proc initFunctions(engine: Engine, script: DeliNode) =
  engine.doFunctionDefs(script)
  #engine.checkFunctionCalls(script)
