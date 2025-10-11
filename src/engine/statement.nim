### Runtime ###

proc doInner(engine: Engine, node: DeliNode) {.inline.} =
  for s in node.sons:
    engine.doStmt(s)

proc doBlock(engine: Engine, node: DeliNode) {.inline.} =
  for stmt in node.sons:
    engine.insertStmt(stmt)
  engine.debugNext()

proc doStmt(engine: Engine, s: DeliNode) =
  let nsons = s.sons.len()
  case s.kind

  of dkBlock,
     dkStatement:    engine.doBlock(s)
  of dkNone:         discard
  of dkInner:        engine.doInner(s)
  of dkJump:         engine.doJump(s)
  of dkVariableStmt: engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkVarDerefStmt: engine.doDerefAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkCloseStmt:    engine.doClose(s.sons[0])
  of dkArgStmt:      engine.doArgStmt(s)
  of dkEnvStmt:      engine.doEnvStmt(s)
  of dkLocalStmt:    engine.doLocalStmt(s)
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
  of dkIncludeStmt:  engine.doIncludeStmt(s)
  of dkRunStmt:      discard engine.doRun(s)

  else:
    todo "doStmt ", s.kind

proc execCurrent(engine: Engine) =
  engine.doStmt(engine.current)
