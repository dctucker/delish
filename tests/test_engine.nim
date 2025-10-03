import os
import ../src/delitypes/ops
import ./common

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

proc DKScript(stmts: varargs[DeliNode]) =
  engine.setup( makeScript(@stmts) )

suite "engine":
  setup:
    engine = newEngine(0)

  test "assign variable":
    DKScript(
      DKVarStmt("x", dkAssignOp, DKStr("foo"))
    )
    check:
      nextVar("x") == "foo"

  test "increment variable":
    DKScript(
      DKVarStmt("x", dkAssignOp, DKInt(3)),
      DKVarStmt("x", dkAppendOp, DKInt(2)),
    )
    check:
      nextVar("x") == 3
      nextVar("x") == 5

  test "local variables":
    DKScript(
      DKVarStmt("x", dkAssignOp, DKInt(4)),
      DK( dkPush ),
      DKLocalStmt("x", dkAssignOp, DKStr("foo")),
      DK( dkPop ),
    )
    check:
      nextVar("x") == 4
      nextVar("x") == 4
      nextVar("x") == "foo"
      nextVar("x") == 4

  test "arguments":
    let arg = DK( dkArg, DeliNode(kind: dkArgShort, argName: "a") )
    DKScript(
      DK( dkArgStmt, DK( dkArgNames, arg ), DK( dkDefaultOp ), DKExpr( DKInt(3) ) ),
      DKVarStmt("x", dkAssignOp, arg),
    )
    next()
    check nextVar("x") == 3

  test "environment":
    DKScript(
      DK( dkEnvStmt, DKVar("USER") ),
      DK( dkEnvStmt, DKVar("PASTRAMI_ON_RYE"), DK( dkDefaultOp ), DK( dkEnvDefault, DKStr("no mayonaise") ) )
    )
    check:
      nextVar("USER") == getEnv("USER")
      nextVar("PASTRAMI_ON_RYE") == "no mayonaise"

  test "include":
    DKScript(
      DK( dkIncludeStmt, DKStr("tests/fixtures/test_include.deli") ),
      DKVarStmt("x", dkAssignOp, DKStr("done"))
    )
    next() # include
    check:
      nextVar("x") == 6
      nextVar("y") == 2
      nextVar("x") == "done"

  test "stream":
    skip

  test "functions":
    let id = DeliNode(kind: dkIdentifier, id: "foo")
    DKScript(
      DKVarStmt("x", dkAssignOp, DKInt(0)),
      DK( dkFunctionDef, id, DK( dkCode,
        DKVarStmt("x", dkAssignOp, DKInt(1)),
      )),
      DK( dkFunctionStmt, DK( dkFunctionCall, DeliNode(kind: dkCallable, sons: @[id]) ) ),
    )
    check engine.nextLen == 3
    check nextVar("x") == 0
    check nextVar("x") == 0
    next()
    check nextVar("x") == 1

  test "for loop":
    DKScript(
      DK( dkForLoop, DKVar("i"), DK( dkIterable, DK( dkArray, DKInt(0), DKInt(1), DKInt(2) ) ),
        DK( dkCode,
          DKVarStmt("x", dkAssignOp, DKVar("i")),
        )
      )
    )
    check engine.nextLen == 1
    next() # for loop expansion
    check engine.nextLen > 1
    check nextVar("x") == 0
    check nextVar("x") == 1
    check nextVar("x") == 2

  test "do loop":
    DKScript(
      DKVarStmt("x", dkAssignOp, DKInt(3)),
      DK( dkDoLoop,
        DK( dkCode,
          DKVarStmt("x", dkRemoveOp, DKInt(1)),
        ), DK( dkCondition, DK( dkComparison,
          DK( dkGtOp ), DKVar("x"), DKInt(0)
        ))
      ),
      DKVarStmt("x", dkAssignOp, DKInt(5)),
    )
    check nextVar("x") == 3
    next() # setup do
    check:
      engine.nextLen() > 1
      nextVar("x") == 2
      nextVar("x") == 1
      nextVar("x") == 0
      nextVar("x") == 5

  test "while loop":
    DKScript(
      DKVarStmt("x", dkAssignOp, DKInt(3)),
      DK( dkWhileLoop,
        DK( dkCondition, DK( dkComparison,
          DK( dkGtOp ), DKVar("x"), DKInt(0)
        )),
        DK( dkCode,
          DKVarStmt("x", dkRemoveOp, DKInt(1)),
        ),
      ),
      DKVarStmt("x", dkAssignOp, DKInt(5)),
    )
    check nextVar("x") == 3
    next() # setup while
    check:
      engine.nextLen() > 1
      nextVar("x") == 2
      nextVar("x") == 1
      nextVar("x") == 0
      nextVar("x") == 5

  test "conditionals":
    DKScript(
      DKVarStmt("y", dkAssignOp, DKFalse),
      DKVarStmt("x", dkAssignOp, DKInt(1)),
      DK( dkConditional,
        DK( dkCondition, DK( dkComparison,
          DK( dkGtOp ), DKVar("x"), DKInt(0)
        )),
        DK( dkCode,
          DKVarStmt("y", dkAssignOp, DKTrue),
        )
      )
    )
    check:
      nextVar("y") == false
      nextVar("x") == 1
    next()
    check nextVar("y") == true

