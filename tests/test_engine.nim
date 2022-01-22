import unittest
import os

import ../src/deliast
import ../src/deliengine

var engine: Engine

proc makeScript(stmts: seq[DeliNode]): DeliNode =
  result = DK( dkScript, DK( dkCode ) )
  for stmt in stmts:
    result.sons[0].sons.add( DK( dkStatement, stmt ) )

proc next() =
  discard engine.doNext()

proc nextVar(v: string): DeliNode =
  next()
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
    next()
    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 3

  test "environment":
    script(
      DK( dkEnvStmt, DKVar("USER") ),
      DK( dkEnvStmt, DKVar("PASTRAMI_ON_RYE"), DK( dkDefaultOp ), DK( dkEnvDefault, DKStr("no mayonaise") ) )
    )
    var u: DeliNode
    u = nextVar("USER")
    check:
      u.kind == dkString
      u.strVal == getEnv("USER")

    u = nextVar("PASTRAMI_ON_RYE")
    check:
      u.kind == dkString
      u.strVal == "no mayonaise"

  test "include":
    skip

  test "stream":
    skip

  test "functions":
    skip

  test "for loop":
    script(
      DK( dkForLoop, DKVar("i"), DK( dkArray, DKInt(0), DKInt(1), DKInt(2) ),
        DK( dkCode,
          DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKExpr( DKVar("i") ) )
        )
      )
    )
    check:
      engine.nextLen == 1

    var i,x: DeliNode

    next() # for loop expansion
    check:
      engine.nextLen > 1

    x = nextVar("x") # assign
    check:
      x.kind == dkInteger
      x.intVal == 0

    x = nextVar("x") # assign
    check:
      x.intVal == 1

    x = nextVar("x") # assign
    check:
      x.intVal == 2

  test "do loop":
    script(
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKInt(3) ),
      DK( dkDoLoop,
        DK( dkCode,
          DK( dkVariableStmt, DKVar("x"), DK( dkRemoveOp ), DKInt(1) ),
        ), DK( dkCondition, DK( dkComparison,
          DK( dkCompGt ), DKVar("x"), DKInt(0)
        ))
      ),
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKInt(5) ),
    )

    var x: DeliNode

    x = nextVar("x")
    check:
      x.intVal == 3

    next() # setup do
    check:
      engine.nextLen() > 1

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 2

    x = nextVar("x")
    check:
      x.intVal == 1

    x = nextVar("x")
    check:
      x.intVal == 0

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 5


  test "while loop":
    script(
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKInt(3) ),
      DK( dkWhileLoop,
        DK( dkCondition, DK( dkComparison,
          DK( dkCompGt ), DKVar("x"), DKInt(0)
        )),
        DK( dkCode,
          DK( dkVariableStmt, DKVar("x"), DK( dkRemoveOp ), DKInt(1) ),
        ),
      ),
      DK( dkVariableStmt, DKVar("x"), DK( dkAssignOp ), DKInt(5) ),
    )
    var x: DeliNode

    next() # setup while
    check:
      engine.nextLen() > 1

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 3

    x = nextVar("x")
    check:
      x.intVal == 2

    x = nextVar("x")
    check:
      x.intVal == 1

    x = nextVar("x")
    check:
      x.intVal == 0

    x = nextVar("x")
    check:
      x.kind == dkInteger
      x.intVal == 5

  test "condition":
    skip

