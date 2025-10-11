### Runtime ###

proc doContinueStmt(engine: Engine) {.inline.} =
  var to = engine.getVariable(".continue")
  engine.setHeads(to.list_node)

proc doBreakStmt(engine: Engine) {.inline.} =
  var to = engine.getVariable(".break")
  engine.setHeads(to.list_node)

proc doReturnStmt(engine: Engine, stmt: DeliNode) {.inline.} =
  engine.printVariables()
  var head_to = engine.getVariable(".return")
  if stmt.sons.len > 0:
    discard engine.retvals.pop()
    engine.retvals.push( engine.evaluate(stmt.sons[0]) )
  engine.setHeads(head_to.list_node)

proc doStmt(engine: Engine, s: DeliNode) =
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

  of dkVariableStmt: engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkVarDerefStmt: engine.doDerefAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkCloseStmt:    engine.doClose(s.sons[0])
  of dkArgStmt:      engine.doArgStmt(s)

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

  of dkConditional:  engine.doConditional(s)
  of dkForLoop:      engine.doForLoop(s)
  of dkWhileLoop:    engine.doWhileLoop(s)
  of dkDoLoop:       engine.doDoLoop(s)
  of dkFunctionDef:  engine.doFunctionDef(s.sons[0], s.sons[1])
  of dkFunctionStmt: discard engine.evaluate(s.sons[0])
  of dkContinueStmt: engine.doContinueStmt
  of dkBreakStmt:    engine.doBreakStmt
  of dkReturnStmt:   engine.doReturnStmt(s)
  of dkPush:         engine.pushLocals()
  of dkPop:          engine.popLocals()
  of dkStreamStmt:   engine.doStream(s.sons)

  of dkIncludeStmt:
    if s.sons.len == 1:
      engine.doInclude(s.sons[0])
      s.addSon DKTrue

  of dkInner:
    for s in s.sons:
      engine.doStmt(s)

  of dkRunStmt:      discard engine.doRun(s)

  else:
    todo "doStmt ", s.kind

proc execCurrent(engine: Engine) =
  engine.doStmt(engine.current)
