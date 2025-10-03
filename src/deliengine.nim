import
  system/exceptions,
  std/[
    lists,
    sequtils,
    streams,
    strutils,
    tables,
    times,
  ],
  ./language/[
    ast,
    parser,
  ],
  ./[
    stacks,
    argument,
    deliscript,
    deliprocess,
  ],
  ./delitypes/[
    casts,
    ops,
    functions,
  ]

include ./engine/[
  common,
  environment,
  engine,
  locals,
  variables,
  arguments,
  fileio,
  processes,
  functions,
  evaluation,
  flow,
  statement,
]

proc newEngine*(debug: int): Engine =
  result = Engine(
    argnum: 1,
    variables:  {:}.toTbl,
    statements: @[deliNone()].toSinglyLinkedList,
    current:    deliNone(),
    debug:      debug
  )
  result.argstack.push(newSeq[Argument]())
  result.clearStatements()
  result.locals.push({:}.toTbl)
  result.retvals.push(DKInt(0))
  result.fds[0] = initFd(stdin)
  result.fds[1] = initFd(stdout)
  result.fds[2] = initFd(stderr)
  result.readhead  = result.statements.head
  result.writehead = result.statements.head

proc newEngine*(scr: DeliNode, debug: int): Engine =
  result = newEngine(debug)
  result.setup(scr)

proc retval*(engine: Engine): DeliNode =
  engine.retvals.peek()

proc readCurrent(engine: Engine) =
  engine.current = engine.readhead.value

proc isEnd(engine: Engine): bool =
  return engine.readhead == nil or engine.readhead.next == nil

proc advance(engine: Engine) =
  engine.setHeads(engine.readhead.next)

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

    #try:
    #engine.printStatements(true)
    engine.execCurrent()
    #engine.printStatements(true)
    #except RuntimeError as e:
    #  if engine.isEnd():
    #    stderr.write "REACHED END", engine.writehead.value.line, "\n"
    #  engine.advance()
    #  raise e

    if engine.isEnd():
      break
    engine.advance()
