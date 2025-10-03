### Flow ###

proc setupConditional(engine: Engine, cond: DeliNode, stmt: DeliNode, line: int): DeliNode =
  var conditional = DK( dkConditional, cond,
    DK( dkCode, DKInner( line, stmt ) )
  )
  conditional.line = cond.line

  engine.insertStmt( DKInner( -line, conditional ) )
  return conditional

proc doConditional(engine: Engine, cond: DeliNode) =

  if cond.list_node == nil:
    debug 3:
      stderr.write("\27[36m")
      for son in cond.sons:
        stderr.write "   - ", son.line, ": ", son.repr, "\n"
      stderr.write("\27[0m")

    assert cond.sons.len mod 2 == 0

    var jump_done = DKJump(cond.sons[^1].line + 1)

    var i: int = 0
    var sons = cond.sons
    while i < sons.len:
      let condition = sons[i]
      let code = sons[i + 1]

      var jump_true = DKJump(condition.line)

      var conditional = cond
      if i == 0:
        cond.sons = @[condition, jump_true]
        cond.line = condition.line
      else:
        conditional = DeliNode(kind: dkConditional, sons: @[
            condition,
            jump_true,
        ], lineNumber: condition.line)
        engine.insertStmt(conditional)

      engine.insertStmt(code)
      engine.insertStmt(DKInner(-code.line - 1, jump_done))
      conditional.list_node = engine.writehead

      i += 2
    jump_done.list_node = engine.writehead

    debug 2:
      engine.printStatements()

  let condition = cond.sons[0]
  let eval = engine.evaluate(condition)
  let ok = engine.isTruthy(eval)
  if not ok:
    engine.setHeads(cond.list_node)

  engine.debugNext()

proc doDoLoop(engine: Engine, loop: DeliNode) =
  if loop.list_node == nil:
    let code = loop.sons[0]
    let condition = loop.sons[1]
    let top_line = -loop.line
    let end_line = -code.sons[^1].line

    var jump_break    = DK(dkJump)
    var jump_continue = DK(dkJump)

    engine.setupPush(top_line, {
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTbl)

    jump_continue.list_node = engine.write_head
    engine.insertStmt(code.sons)

    discard engine.setupConditional(condition, DKContinue(end_line - 1), end_line - 1)

    jump_break.list_node = engine.writehead
    engine.setupPop( end_line - 1 )
    loop.list_node = jump_continue.list_node

  engine.debugNext()

proc doWhileLoop(engine: Engine, loop: DeliNode) =
  if loop.list_node == nil:
    let condition = loop.sons[0]
    let code      = loop.sons[1]
    let top_line = -loop.line
    let end_line = -code.sons[^1].line

    var jump_break    = DK(dkJump)
    var jump_continue = DK(dkJump)

    engine.setupPush(top_line, {
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTbl)

    jump_continue.list_node = engine.write_head
    discard engine.setupConditional( DK(dkBoolNot, condition), DKBreak(top_line), top_line )
    engine.insertStmt(code.sons)

    engine.insertStmt( DKInner(end_line - 1,
      DK( dkContinueStmt )
    ))

    jump_break.list_node = engine.writehead
    engine.setupPop( end_line - 1 )

    loop.sons.add(jump_break)
    loop.sons.add(jump_continue)
    loop.list_node = jump_continue.list_node

  engine.debugNext()

proc setupNext(engine: Engine, variable, iter: DeliNode): DeliNode =
  let things = engine.evaluate( iter.sons[0] )
  case things.kind
  of dkArray:
    let counter  = DKVar(".counter")
    result = DKInner( -variable.line,
      DK( dkVariableStmt, # $var = $things..counter
        variable, DK(dkAssignOp), DK(dkVarDeref, things, counter),
      ),
      DK( dkVariableStmt, # $.counter += 1
        counter, DK(dkAppendOp), DKInt(1),
      ),
    )
  else:
    todo "setupNext " & $things.kind
  engine.insertStmt(result)

proc doForLoop(engine: Engine, loop: DeliNode) =
  let variable = loop.sons[0]
  let iter     = loop.sons[1]
  let code     = loop.sons[2]

  if loop.list_node == nil:
    let top_line = -loop.line
    let end_line = -code.sons[^1].line - 1
    let counter  = DKVar(".counter")

    var jump_break    = DKJump(end_line + 1)
    var jump_continue = DKJump(end_line + 1)

    engine.setupPush(top_line, {
      ".counter" : DKInt(0),
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTbl)

    jump_continue.list_node = engine.write_head
    discard engine.setupNext(variable, iter)

    var condition = DK( dkComparison, DK(dkEqOp), deliNone(), variable )
    condition.line = top_line
    discard engine.setupConditional(condition, DKBreak(top_line), top_line)

    engine.insertStmt( code.sons )
    engine.insertStmt( DKInner(end_line, DK(dkContinueStmt) ))

    jump_break.list_node = engine.writehead
    engine.setupPop( end_line - 1 )
    loop.list_node = jump_continue.list_node

    debug 2:
      engine.printStatements()

  engine.debugNext()
