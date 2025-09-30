### Locals ###

proc printLocals(engine: Engine) =
  debug 2:
    let layer = engine.locals.peek()
    echo "\27[36m== Local Variables (", layer.len(), ") =="
    for k,v in layer:
      stdout.write("  $", k, " = ")
      stdout.write(printValue(v))
      stdout.write("\n")

proc assignLocal(engine: Engine, key: string, value: DeliNode) =
  var locals = engine.locals.popUnsafe()
  locals[key] = value
  engine.locals.push(locals)
  debug 3:
    echo "  locals = ", $(engine.locals)

proc pushLocals(engine: Engine) =
  engine.locals.push(engine.locals.peek())
  engine.argnum = 1
  var arguments: seq[Argument] = @[]
  engine.argstack.push(arguments)
  engine.retvals.push(deliNone())

  #debug 3:
  #  echo "  push locals ", engine.locals

proc popLocals(engine: Engine) =
  debug 3:
    echo "  pop locals before ", engine.locals, ", retvals ", engine.retvals
  discard engine.locals.popUnsafe()
  discard engine.argstack.popUnsafe()
  engine.assignLocal(".returned", engine.retvals.popUnsafe())
  engine.argnum = 1
  debug 3:
    echo "  pop locals after ", engine.locals, ", retvals ", engine.retvals

proc setupPush(engine: Engine, line: int, table: DeliTable) =
  var inner = DKInner(line, DK(dkPush))
  for k,v in table.pairs():
    inner.sons.add(DK(dkLocalStmt, DKVar(k), DK( dkAssignOp ), v))
  engine.insertStmt(inner)

proc setupPop(engine: Engine, line: int) =
  engine.insertStmt( DKInner(line, DK(dkPop)) )

proc doLocal(engine: Engine, name: DeliNode, default: DeliNode) =
  engine.locals.peekUnsafe[name.varName] = engine.evaluate(default)
