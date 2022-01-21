import unittest

import ../src/deliast
import ../src/deliengine

var engine: Engine

proc makeScript(stmts: seq[DeliNode]): DeliNode =
  result = DK( dkScript, DK( dkCode ) )
  for stmt in stmts:
    result.sons[0].sons.add( DK( dkStatement, stmt ) )

proc nextVar(v: string): DeliNode =
  discard engine.doNext()
  result = engine.getVariable(v)

proc script(stmts: varargs[DeliNode]) =
  engine.setup( makeScript(@stmts) )

suite "engine":
  setup:
    engine = newEngine(0)

  test "assign variable":
    script(
      DK( dkVariableStmt,
        DKVar("x"), DK( dkAssignOp ), DK( dkExpr, DKStr("foo") )
      )
    )

    let x = nextVar("x")
    check:
      x.kind == dkString
      x.strVal == "foo"

  test "increment variable":
    script(
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKExpr( DKInt(3) ) ),
      DK( dkVariableStmt, DKVar("x"), DK( dkAppendOp ), DKExpr( DKInt(2) ) )
    )

    var x: DeliNode
    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 3

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 5

  test "local variables":
    script(
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKExpr( DKInt(4) ) ),
      DK( dkPush ),
      DK( dkLocalStmt, DKVar("x"), DK( dkAssignOp ), DKExpr( DKStr("foo") ) ),
      DK( dkPop ),
    )

    var x: DeliNode
    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 4

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 4

    x = nextVar("x")
    check:
      x.kind == dkString
      x.strVal == "foo"

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 4

  test "arguments":
    let arg = DK( dkArg, DeliNode(kind: dkArgShort, argName: "a") )
    script(
      DK( dkArgStmt, DK( dkArgNames, arg ), DK( dkDefaultOp ), DKExpr( DKInt(3) ) ),
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKExpr( arg ) ),
    )

    var x: DeliNode
    discard engine.doNext()
    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 3

