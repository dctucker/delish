import system/exceptions
import std/lists
import std/sequtils
import std/streams
import std/strutils
import std/tables
import std/times
import stacks
import ./argument
import ./deliast
import ./deliscript
import ./deliparser
import ./deliprocess
import ./delitypes/casts
import ./delitypes/ops
import ./delitypes/functions

include ./engine/common
include ./engine/environment
include ./engine/engine
include ./engine/locals
include ./engine/variables
include ./engine/arguments
include ./engine/fileio
include ./engine/processes
include ./engine/functions
include ./engine/evaluation
include ./engine/flow
include ./engine/runtime

proc newEngine*(debug: int): Engine =
  result = Engine(
    argnum: 1,
    variables:  initTable[string, DeliNode](),
    statements: @[deliNone()].toSinglyLinkedList,
    current:    deliNone(),
    debug:      debug
  )
  result.argstack.push(newSeq[Argument]())
  result.clearStatements()
  result.locals.push(initTable[string, DeliNode]())
  result.retvals.push(DKInt(0))
  result.fds[0] = initFd(stdin)
  result.fds[1] = initFd(stdout)
  result.fds[2] = initFd(stderr)
  result.readhead  = result.statements.head
  result.writehead = result.statements.head

proc newEngine*(script: DeliNode, debug: int): Engine =
  result = newEngine(debug)
  result.setup(script)

proc retval*(engine: Engine): DeliNode =
  engine.retvals.peek()

proc doNext*(engine: Engine): int =
  if engine.isEnd():
    return -1
  engine.readCurrent()
  result = engine.current.line
  engine.execCurrent()
  if not engine.isEnd():
    engine.advance()
    engine.readCurrent()

  while engine.current.kind == dkInner:
    if engine.isEnd():
      return -1
    engine.execCurrent()
    engine.advance()
    engine.readCurrent()

iterator tick*(engine: Engine): int =
  debug 3:
    echo "\nRunning program..."
  while true:
    engine.readCurrent()
    if engine.debug > 1:
      yield engine.current.line
    else:
      if engine.current.kind != dkInner:
        yield engine.current.line
    debug 3:
      engine.printStatements()
    engine.execCurrent()
    if engine.isEnd():
      break
    engine.advance()
