type DeliError* = object of CatchableError
type RuntimeError* = ref object of DeliError
type SetupError* = ref object of DeliError
type InterruptError* = ref object of DeliError

type
  FileDesc = ref object
    file:       File
    handle:     FileHandle
    stream:     Stream

  Engine* = ref object
    debug*:     int
    argstack:   Stack[ seq[Argument] ]
    argnum:     int
    variables:  DeliTable
    locals:     Stack[ DeliTable ]
    envars:     Table[string, string]
    functions:  DeliTable
    current:    DeliNode
    fds:        Table[int, FileDesc]
    statements: DeliList
    readhead:   DeliListNode
    writehead:  DeliListNode
    tail:       DeliListNode
    returns:    Stack[ DeliListNode ]
    retvals:    Stack[ DeliNode ]

template debug(level: int, code: untyped) =
  if engine.debug >= level:
    code
    #stdout.write("\27[0m")

proc close         (fd: FileDesc)
proc evaluate      (engine: Engine, val: DeliNode): DeliNode
proc doOpen        (engine: Engine, nodes: seq[DeliNode]): DeliNode
proc doStmt        (engine: Engine, s: DeliNode)
proc initArguments (engine: Engine, script: DeliNode)
proc initIncludes  (engine: Engine, script: DeliNode)
proc initFunctions (engine: Engine, script: DeliNode)
proc initScript    (engine: Engine, script: DeliNode)
proc assignVariable(engine: Engine, key: string, value: DeliNode)
proc setHeads      (engine: Engine, list: DeliListNode)

proc getStreamNumber(node: DeliNode): int =
  return node.intVal
