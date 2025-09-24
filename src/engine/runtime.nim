### Runtime ###

proc doStmt(engine: Engine, s: DeliNode) =
  echo s.kind

  let nsons = s.sons.len()
  case s.kind
  of dkNone:
    discard
  of dkStatement, dkBlock:
    for stmt in s.sons:
      engine.insertStmt(stmt)
    engine.debugNext()
  of dkJump:
    engine.setHeads(s.list_node)
    engine.debugNext()
  of dkVariableStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkCloseStmt:
    engine.doClose(s.sons[0])
  of dkArgStmt:
    if s.sons[0].kind == dkVariable:
      var shifted = engine.shift()
      var value = if shifted.kind != dkNone:
        shifted
      elif nsons > 1: # DefaultOp ArgDefault Expr
        s.sons[2].sons[0]
      else:
        deliNone()
      engine.assignVariable(s.sons[0].varName, value)
    else:
      if nsons > 1:
        engine.doArg(s.sons[0].sons, s.sons[2].sons[0])
      else:
        engine.doArg(s.sons[0].sons, deliNone())
    engine.printVariables()
  of dkEnvStmt:
    if nsons > 1:
      engine.doEnv(s.sons[0], s.sons[1].kind, s.sons[2])
    else:
      engine.doEnv(s.sons[0])
  of dkLocalStmt:
    if nsons > 2:
      engine.doLocal(s.sons[0], s.sons[2])
    else:
      engine.doLocal(s.sons[0], deliNone())
  of dkConditional:
    engine.doConditional(s)
  of dkForLoop:
    engine.doForLoop(s)
  of dkWhileLoop:
    engine.doWhileLoop(s)
  of dkDoLoop:
    engine.doDoLoop(s)
  of dkFunction:
    engine.doFunctionDef(s.sons[0], s.sons[1])
  of dkFunctionStmt:
    let call = s.sons[0]
    discard engine.evalFunctionCall(call.sons[0], call.sons[1 .. ^1])
  of dkContinueStmt:
    var to = engine.getVariable(".continue")
    engine.setHeads(to.list_node)
  of dkBreakStmt:
    var to = engine.getVariable(".break")
    engine.setHeads(to.list_node)
  of dkReturnStmt:
    engine.printVariables()
    var head_to = engine.getVariable(".return")
    if nsons > 0:
      discard engine.retvals.pop()
      engine.retvals.push( engine.evaluate(s.sons[0]) )
    engine.setHeads(head_to.list_node)
  of dkPush:
    engine.pushLocals()
  of dkPop:
    engine.popLocals()
  of dkStreamStmt:
    engine.doStream(s.sons)
  of dkIncludeStmt:
    if s.sons.len == 1:
      engine.doInclude(s.sons[0])
      s.sons.add(DKTrue)
  of dkInner:
    for s in s.sons:
      engine.doStmt(s)
  of dkRunStmt:
    discard engine.doRun(s)
  else:
    todo "doStmt ", s.kind

proc execCurrent(engine: Engine) =
  engine.doStmt(engine.current)

