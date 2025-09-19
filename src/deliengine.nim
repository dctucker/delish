import system/exceptions
import std/tables
import std/lists
import os
import std/streams
import deliops
import delicast
import deliast
import strutils
import sequtils
import stacks
import deliargs
import deliscript
import deliparser
import deliprocess
import delifile

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

proc initFd(file: File): FileDesc =
  FileDesc(
    file: file,
    stream: newFileStream(file),
    handle: file.getOsFileHandle(),
  )

proc initFd(handle: FileHandle, stream: Stream): FileDesc =
  FileDesc(
    file: nil,
    stream: stream,
    handle: handle,
  )

proc addFd(engine: Engine, handle: FileHandle, stream: Stream): int =
  result = cint handle
  engine.fds[result] = initFd(handle, stream)

proc retval*(engine: Engine): DeliNode =
  engine.retvals.peek()

proc arguments(engine: Engine): seq[Argument] =
  engine.argstack.peek()

proc addArgument(engine: Engine, arg: Argument) =
  var arguments = engine.argstack.pop()
  arguments.add(arg)
  engine.argstack.push(arguments)

proc close         (fd: FileDesc)
proc evaluate      (engine: Engine, val: DeliNode): DeliNode
proc doOpen        (engine: Engine, nodes: seq[DeliNode]): DeliNode
proc doStmt        (engine: Engine, s: DeliNode)
proc initArguments (engine: Engine, script: DeliNode)
proc initIncludes  (engine: Engine, script: DeliNode)
proc initFunctions (engine: Engine, script: DeliNode)
proc loadScript    (engine: Engine, script: DeliNode)
proc assignVariable(engine: Engine, key: string, value: DeliNode)

proc clearStatements*(engine: Engine) =
  engine.statements = @[deliNone()].toSinglyLinkedList

proc setup*(engine: Engine, script: DeliNode) =
  engine.initArguments(script)
  engine.initIncludes(script)
  engine.initFunctions(script)
  engine.loadScript(script)

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

### Engine ###

template debug(level: int, code: untyped) =
  if engine.debug >= level:
    code
    #stdout.write("\27[0m")

proc setHeads(engine: Engine, list: DeliListNode) =
  engine.readhead = list
  engine.writehead = engine.readhead

proc insertStmt(engine: Engine, node: DeliNode) =
  if node.script == nil:
    if engine.current.kind != dkNone:
      node.script = engine.current.script
  if node.kind in @[ dkStatement, dkBlock, dkCode ]:
    for s in node.sons:
      engine.insertStmt(s)
    return

  var sw = engine.writehead.next
  let listnode = newSinglyLinkedNode[DeliNode](node)
  engine.writehead.next = listnode
  listnode.next = sw
  engine.writehead = listnode

proc insertStmt(engine: Engine, nodes: seq[DeliNode]) =
  for node in nodes:
    engine.insertStmt(node)

proc loadScript(engine: Engine, script: DeliNode) =
  for s in script.sons:
    for s2 in s.sons:
      engine.insertStmt(s2)
  engine.tail = engine.writehead
  engine.insertStmt(DKInner(0, deliNone()))
  debug 3:
    echo engine.statements
  engine.setHeads(engine.statements.head.next)

  engine.assignVariable(".return", DeliNode( kind: dkJump, node: engine.tail ))

proc sourceFile*(engine: Engine): string =
  result = ""
  if engine.current.script != nil:
    result = engine.current.script.filename

proc sourceLine*(engine: Engine): string =
  return engine.current.script.getLine( engine.current.line )

proc lineInfo*(engine: Engine): string =
  var filename: string
  var sline: string

  let line = engine.current.line
  sline = getOneliner(engine.current)
  if engine.current.script != nil:
    filename = engine.current.script.filename
    sline = engine.current.script.getLine(abs(line))

  let delim = if line > 0:
    ":"
  else:
    "."
  let linenum = "\27[1;30m" & filename & delim & $abs(line)
  let source = " \27[0;34;4m" & sline
  let parsed = "\27[1;24m " & repr(engine.current)
  return linenum & source & parsed & "\27[0m"

proc doInclude(engine: Engine, included: DeliNode) =
  let filename = engine.evaluate(included).toString()
  let script = loadScript(filename)
  let parser = Parser(script: script, debug: engine.debug)
  let parsed = parser.parse()
  for s in parsed.sons:
    engine.insertStmt(s.sons)

proc debugNext(engine: Engine) =
  debug 3:
    stdout.write("\27[30;1m  next = ")
    var head = engine.readhead.next
    while head != nil:
      let l = head.value.line
      var line = ":" & $l
      if l < 0:
        line = "." & $(-l)
      stdout.write("\27[4m", line, "\27[24m ")
      head = head.next
    stdout.write("\27[0m\n")

proc nextLen*(engine: Engine): int =
  result = 0
  var head = engine.readhead.next
  while head != nil:
    result += 1
    head = head.next

proc runtimeError(engine: Engine, msg: varargs[string,`$`]) =
  engine.readhead.next = nil
  var message = ""
  for m in msg:
    message &= m
  raise RuntimeError(msg: message)

proc setupError(engine: Engine, msg: varargs[string,`$`]) =
  engine.readhead.next = nil
  var message = ""
  for m in msg:
    message &= m
  raise SetupError(msg: "(setup) " & message)

proc teardown(engine: Engine) =
  for k,v in engine.fds.pairs():
    v.close()


### Environment ###

proc printEnvars(engine: Engine) =
  debug 2:
    echo "ENV = ", $(engine.envars)
    #echo "--- available envars ---"
    #for k,v in envPairs():
    #  stdout.write(k, " ")
    #stdout.write("\n")

proc assignEnvar(engine: Engine, key: string, value: string) =
  putEnv(key, value)
  engine.envars[key] = value
  engine.printEnvars()

proc doEnv(engine: Engine, name: DeliNode, op: DeliKind = dkNone, default: DeliNode = deliNone()) =
  let key = name.varName
  let def = if default.isNone():
    ""
  else:
    engine.evaluate(default).toString()
  if op == dkAssignOp:
    putEnv(key, def)
  engine.envars[ name.varName ] = getEnv(key, def)
  engine.printEnvars()


### Locals ###

proc printLocals(engine: Engine) =
  let layer = engine.locals.peek()
  debug 2:
    echo "\27[36m== Local Variables (", layer.len(), ") =="
    for k,v in layer:
      stdout.write("  $", k, " = ")
      stdout.write(printValue(v))
      stdout.write("\n")

proc assignLocal(engine: Engine, key: string, value: DeliNode) =
  var locals = engine.locals.pop()
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

proc setupPush(engine: Engine, line: int, table: DeliTable) =
  var inner = DKInner(line, DK(dkPush))
  for k,v in table.pairs():
    inner.sons.add(DK(dkLocalStmt, DKVar(k), DK( dkAssignOp ), v))
  engine.insertStmt(inner)

proc popLocals(engine: Engine) =
  debug 3:
    echo "  pop locals before ", engine.locals, ", retvals ", engine.retvals
  discard engine.locals.pop()
  discard engine.argstack.pop()
  engine.assignLocal(".returned", engine.retvals.pop())
  engine.argnum = 1
  debug 3:
    echo "  pop locals after ", engine.locals, ", retvals ", engine.retvals

proc setupPop(engine: Engine, line: int) =
  engine.insertStmt( DKInner(line, DK(dkPop)) )

proc doLocal(engine: Engine, name: DeliNode, default: DeliNode) =
  var locals = engine.locals.pop()
  locals[name.varName] = engine.evaluate(default)
  engine.locals.push(locals)


### Variables ###

proc printVariables(engine: Engine) =
  debug 2:
    echo "\27[36m== Engine Variables (", engine.variables.len(), ") =="
    for k,v in engine.variables:
      stdout.write("  $", k, " = ")
      stdout.write(printValue(v))
      stdout.write("\n")

proc getVariable*(engine: Engine, name: string): DeliNode =
  var stack = engine.locals.toSeq()
  for i in countdown(stack.high, stack.low):
    let locals = stack[i]
    if locals.contains(name):
      return locals[name]
  if engine.variables.contains(name):
    return engine.variables[name]
  elif engine.envars.contains(name):
    return DeliNode(kind: dkString, strVal: engine.envars[name])
  else:
    engine.runtimeError("Unknown variable: $" & name)

proc evalVarDeref(engine: Engine, vard: DeliNode): DeliNode =
  #echo "evalVarDeref ", vard.repr
  let variable = vard.sons[0]
  case variable.kind
  of dkVariable:
    result = engine.getVariable(variable.varName)
  of dkArray:
    result = variable
  else:
    todo "evalVarDeref ", variable.kind
  #echo result

  for son in vard.sons[1 .. ^1]:
    case result.kind
    of dkObject, dkRan:
      let kind = ($result.kind)[2 .. ^1]
      let str = son.toString()
      if str notin result.table:
        engine.runtimeError("$" & variable.varName & " does not contain \"" & str & "\"")
      result = result.table[str]
    of dkArray:
      #echo engine.evaluate(son.repr).repr
      engine.printLocals()
      let idx = engine.evaluate(son).intVal
      if idx < result.sons.len:
        result = result.sons[idx]
      else:
        result = deliNone()
    of dkPath:
      if son.kind == dkIdentifier:
        result = result.pathFunction(son.id)
      else:
        result = deliNone()
      if result.kind == dkNone:
        todo "evalVarDeref ", result.kind, " using ", $son
      #result = PathObject.
    else:
      todo "evalVarDeref ", result.kind, " using ", son.kind

proc assignVariable(engine: Engine, key: string, value: DeliNode) =
  debug 3:
    stdout.write "  "
  if engine.locals.peek().contains(key):
    engine.assignLocal(key, value)
    debug 3:
      stdout.write "local "
  elif engine.envars.contains(key):
    engine.assignEnvar(key, value.toString())
    engine.variables[key] = value
  else:
    engine.variables[key] = value
  debug 3:
    echo "$", key, " = ", $value

proc varAssignLazy(engine: Engine, key: DeliNode, op: DeliNode, value: DeliNode) =
  if value.kind == dkLazy:
    engine.insertStmt( DKInner(engine.current.line,
       DK( dkVariableStmt, key, op, value.sons[0])
    ))
  else:
    engine.assignVariable(key.varName, value)

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, expr: DeliNode) =
  let val = if expr.kind == dkExpr:
      expr.sons[0]
    else:
      expr
  case op.kind
  of dkAssignOp:
    let value = engine.evaluate(val)
    engine.varAssignLazy(key, op, value)
    debug 3:
      echo key, " = " & value.repr
  of dkAppendOp:
    let variable = engine.getVariable(key.varName)
    let value = if val.kind == dkVarDeref:
      engine.evalVarDeref(val)
    else:
      val
    debug 3:
      echo variable, " += ", value.repr
    engine.varAssignLazy(key, op, variable + value)
  of dkRemoveOp:
    let variable = engine.getVariable(key.varName)
    let value = if val.kind == dkVarDeref:
      engine.evalVarDeref(val)
    else:
      val
    debug 3:
      echo variable, " -= ", value.repr
    let out_value = variable - value
    engine.assignVariable(key.varName, out_value)
  else:
    todo "assign ", op.kind


### Arguments ###

proc printArguments(engine: Engine) =
  debug 2:
    echo "\27[36m== Engine Arguments =="
    if engine.arguments.len == 0:
      stdout.write("(none)\27[0m\n")
      return
    let longest = engine.arguments.map(proc(x:Argument):int =
      x.long_name.len()
    ).max()
    for arg in engine.arguments:
      stdout.write("  ")
      if arg.short_name != "":
        stdout.write("-", arg.short_name)
      else:
        stdout.write("  ")
      if arg.long_name != "":
        stdout.write(" --", arg.long_name)
      else:
        stdout.write("   ")
      stdout.write(repeat(" ", longest-arg.long_name.len()))
      stdout.write("  = ")
      stdout.write($(arg.value))
      stdout.write("\n")
    stdout.write("\27[0m")

proc getArgument(engine: Engine, arg: DeliNode): DeliNode =
  case arg.kind
  of dkArgShort:
    return findArgument(engine.arguments, Argument(short_name: arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name: arg.argName)).value
  else:
    todo "getArgument ", arg.kind

proc shift(engine: Engine): DeliNode =
  if engine.argstack.len == 1:
    result = nth(engine.argnum)
  else:
    let args = engine.getVariable(".args")
    result = args.sons[engine.argnum - 1]
  inc engine.argnum

proc doArg(engine: Engine, names: seq[DeliNode], default: DeliNode) =
  let arg = Argument()
  for name in names:
    case name.sons[0].kind
    of dkArgShort: arg.short_name = name.sons[0].argName
    of dkArgLong:  arg.long_name  = name.sons[0].argName
    else:
      todo "arg ", name.sons[0].kind

  var eng_arg = findArgument(engine.arguments, arg)

  if eng_arg.isNone():
    arg.value = engine.evaluate(default)
    engine.addArgument(arg)
    #engine.printArguments()
    #echo "\n"


proc doArgStmts(engine: Engine, node: DeliNode) =
  case node.kind
  of dkStatement:
    engine.doArgStmts(node.sons[0])
  of dkArgStmt:
    engine.doStmt(node)
  of dkCode:
    for son in node.sons:
      engine.doArgStmts(son)
  else:
    discard

proc doIncludes(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkScript, dkCode, dkStatement:
    for n in node.sons:
      engine.doIncludes(n)
  of dkIncludeStmt:
    engine.doStmt(node)
  else:
    discard

proc doFunctionDefs(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkFunction:
    engine.doStmt(node)
  else:
    for son in node.sons:
      engine.doFunctionDefs(son)

proc checkFunctionCalls(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkFunctionStmt:
    let id = node.sons[0].sons[0].id
    if id notin engine.functions:
      engine.setupError("Unknown function: \"" & id & "\" at " & node.script.filename & ":" & $node.line)
  else:
    for son in node.sons:
      engine.checkFunctionCalls(son)

proc initFunctions(engine: Engine, script: DeliNode) =
  engine.doFunctionDefs(script)
  engine.checkFunctionCalls(script)

proc initIncludes(engine: Engine, script: DeliNode) =
  engine.doIncludes(script)

proc initArguments(engine: Engine, script: DeliNode) =
  for stmt in script.sons:
    engine.doArgStmts(stmt)
  engine.argnum = 1

  engine.printArguments()
  debug 3:
    echo "checking user arguments"

  for arg in user_args:
    debug 3:
      echo arg
    if arg.isFlag():
      let f = findArgument(engine.arguments, arg)
      if f.isNone():
        engine.setupError("Unknown argument: " & arg.long_name)
      else:
        if arg.value.isNone():
          arg.value = DeliNode(kind: dkBoolean, boolVal: true)
        f.value = arg.value
  debug 3:
    engine.printArguments()


### Processes ###

proc doRun(engine: Engine, run: DeliNode): DeliNode =
  var args = newSeq[string]()
  for inv in run.sons[0].sons:
    args.add inv.strVal
  var p = newDeliProcess(args)
  result = p.node

  try:
    p.start
  except OSError as e:
    p.exit = e.errorCode
    engine.runtimeError(e.msg)

  let i = engine.addFd(p.handles[0], p.streams[0])
  let o = engine.addFd(p.handles[1], p.streams[1])
  let e = engine.addFd(p.handles[2], p.streams[2])

  let output = engine.fds[o].stream.readAll()
  result.table["out"] = DKStr(output)

  p.wait
  p.close


### Functions ###

proc doFunctionDef(engine: Engine, id: DeliNode, code: DeliNode) =
  if id.id in engine.functions:
    return
  engine.functions[id.id] = code
  debug 3:
    echo "define ", engine.functions

proc evalFunctionCall(engine: Engine, fun: DeliNode, args: seq[DeliNode]): DeliNode =
  result = DK( dkLazy, DKVar(".returned") )
  var code: DeliNode

  case fun.kind
  of dkIdentifier:
    if fun.id notin engine.functions:
      engine.runtimeError("Unknown function: " & fun.id)
    code = engine.functions[fun.id]
  of dkVarDeref:
    code = engine.evaluate(fun)
  else:
    todo "evalFunctionCall ", fun

  var jump_return = DeliNode(kind: dkJump, line: -code.sons[0].line + 1)

  #for a in args:
  #  arguments.add(Argument(value: a))

  engine.setupPush( -code.sons[0].line + 1, {
    ".return": jump_return,
    ".args"  : DeliNode(kind: dkArray, sons: args),
    ".revtal": result,
  }.toTable)

  for s in code.sons:
    engine.insertStmt(s)

  let end_line = -code.sons[^1].line - 1
  jump_return.node = engine.writehead
  engine.setupPop(end_line)

  engine.debugNext()


### Evaluation ###

proc isTruthy(engine: Engine, node: DeliNode): bool =
  case node.kind
  of dkBoolean: return node.boolVal
  else:
    return false

proc evalMath(engine: Engine, op, v1, v2: DeliNode): DeliNode =
  case op.kind
  of dkAddOp: return v1 + v2
  of dkSubOp: return v1 - v2
  of dkMulOp: return v1 * v2
  of dkDivOp: return v1 / v2
  else:
    return deliNone()

proc evalComparison(engine: Engine, op, v1, v2: DeliNode): DeliNode =
  #echo "compare ", v1, op, v2
  let val = case op.kind
  of dkCompEq: v1 == v2
  of dkCompNe: v1 != v2
  of dkCompGt: v1 >  v2
  of dkCompGe: v1 >= v2
  of dkCompLt: v1 <  v2
  of dkCompLe: v1 <= v2
  else:
    todo "evalComparison ", $op
    false
  return DeliNode(kind: dkBoolean, boolVal: val)

proc evalCondExpr(engine: Engine, op: DeliNode, v1: DeliNode, v2: DeliNode): DeliNode =
  case op.kind
  of dkBoolAnd:
    let v1 = engine.evaluate(v1).toBoolean()
    if v1.boolVal == false:
      return v1
    return engine.evaluate(v2).toBoolean()
  of dkBoolOr:
    let v1 = engine.evaluate(v1).toBoolean()
    if v1.boolVal == true:
      return v1
    return engine.evaluate(v2).toBoolean()
  else:
    todo "evalCondExpr ", op.kind

proc evalExpression(engine: Engine, expr: DeliNode): DeliNode =
  result = expr
  while result.kind == dkExpr:
    let s = result.sons[0]
    #echo s.kind
    result = engine.evaluate(s)

proc getStreamNumber(node: DeliNode): int =
  return node.intVal

proc evaluateStream(engine: Engine, stream: DeliNode): FileDesc =
  #let num = if stream.sons.len() > 0:
  #  engine.variables[stream.sons[0].varName].intVal
  #else:
  #  stream.intVal
  let num = engine.evaluate(stream).getStreamNumber()
  if engine.fds.contains(num):
    return engine.fds[num]

proc evalPairKey(engine: Engine, k: DeliNode): string =
  case k.kind
  of dkString:     k.strVal
  of dkIdentifier: k.id
  of dkExpr:       engine.evalPairKey( engine.evaluate(k) )
  else:
    todo "evaluate Object with key ", k.kind
    ""

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkBoolean, dkString, dkIdentifier, dkInteger, dkPath, dkStrBlock, dkStrLiteral, dkJump, dkNone, dkRegex, dkCode:
    return val
  of dkLazy:
    return val.sons[0]
  of dkStream,
    dkEnvDefault,
    dkCondition,
    dkBoolExpr:
    return engine.evaluate( val.sons[0] )
  of dkStreamIn:  return DeliNode(kind: dkStream, intVal: 0)
  of dkStreamOut: return DeliNode(kind: dkStream, intVal: 1)
  of dkStreamErr: return DeliNode(kind: dkStream, intVal: 2)
  of dkArray:
    result = DeliNode(kind: dkArray)
    for son in val.sons:
      result.sons.add(engine.evaluate(son))
    return result
  of dkObject:
    result = DK( dkObject )
    for pair in val.sons:
      let str = engine.evalPairKey( pair.sons[0] )
      result.table[str] = engine.evaluate(pair.sons[1])
    echo printValue(result)
    return result
  of dkRunStmt:
    let ran = engine.doRun(val)
    return ran
  of dkExpr:
    return engine.evalExpression(val)
  of dkVariable:
    return engine.getVariable(val.varName)
  of dkVarDeref:
    return engine.evalVarDeref(val)
  of dkArg:
    debug 3:
      stdout.write "  dereference ", val.sons[0]
    let arg = engine.getArgument(val.sons[0])
    #if arg.isNone(): engine.runtimeError("Undeclared argument: " & val.sons[0].argName)
    result = engine.evaluate(arg)
    debug 3:
      echo " = ", $result
  of dkArgExpr:
    let arg = val.sons[0]
    let aval = engine.evalExpression(val.sons[1])
    result = DK(dkArray, arg, aval)
  of dkOpenExpr:
    return engine.doOpen(val.sons)
  of dkBoolNot:
    return not engine.evaluate( val.sons[0] ).toBoolean()
  of dkCondExpr:
    let v1 = val.sons[1]
    let v2 = val.sons[2]
    return engine.evalCondExpr( val.sons[0], v1, v2 )
  of dkComparison:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalComparison(val.sons[0], v1, v2)
  of dkMathExpr:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalMath(val.sons[0], v1, v2)
  of dkFunctionCall:
    return engine.evalFunctionCall(val.sons[0], val.sons[1 .. ^1])
  of dkCast:
    return engine.evaluate(val.sons[1]).toKind(val.sons[0].kind)
  else:
    todo "evaluate ", val.kind
    return deliNone()


### File I/O

proc getRedirOpenMode(node: DeliNode): FileMode =
  case node.kind
  of dkRedirReadOp:
    return fmRead
  of dkRedirWriteOp:
    return fmWrite
  of dkRedirAppendOp:
    return fmAppend
  of dkRedirDuplexOp:
    return fmReadWrite
  else:
    todo "redir open mode ", node.kind

proc doOpen(engine: Engine, nodes: seq[DeliNode]): DeliNode =
  result = deliNone()
  var variable: string
  var mode = fmReadWrite
  var path: string
  for node in nodes[0 .. ^1]:
    case node.kind
    of dkVariable:
      variable = node.varName
    of dkPath:
      path = node.strVal
    of dkRedirOp:
      mode = getRedirOpenMode(node.sons[0])
    else:
      todo "open ", node.kind
  try:
    let file = open(path, mode)
    let num = file.getOsFileHandle()
    engine.fds[num] = initFd(file)
    result = DeliNode(kind: dkStream, intVal: num)
    engine.variables[variable] = result
  except IOError:
    engine.runtimeError("Unable to open: " & path)

proc doStream(engine: Engine, nodes: seq[DeliNode]) =
  var fd: FileDesc
  #for node in nodes: todo "doStream " & $node.kind
  let first_node = nodes[0]
  if first_node.kind == dkVariable:
    let num = engine.variables[first_node.varName].getStreamNumber()
    if engine.fds.contains(num):
      fd = engine.fds[num]
    else:
      engine.runtimeError("stream " & $num & " does not exist")
  elif first_node.kind == dkStream:
    fd = engine.evaluateStream(first_node)
  else:
    todo "doStream first_node " & $first_node.kind

  var str: string
  let last_node = nodes[^1]
  for expr in last_node.sons:
    #echo expr.repr
    let eval = engine.evaluate(expr)
    #echo eval.repr
    case eval.kind
    of dkStream:
      let input = engine.fds[eval.intVal]
      const buflen = 4096
      var buffer: array[buflen,char]
      while true:
        let bytes = input.file.readChars(buffer)
        let written = fd.file.writeChars(buffer, 0, bytes)
        if written < bytes:
          todo "handle underrun"
        if bytes < buflen:
          break
      fd.file.flushFile()
    else:
      #todo "doStream last_node " & $eval.kind
      str = eval.toString()
      #echo str.repr
      fd.file.write(str)
      #if i < last_node.sons.len - 1:
      #  fd.file.write(" ")
  fd.file.write("\n")

proc close(fd: FileDesc) =
  fd.stream.flush
  fd.stream.close

proc doClose(engine: Engine, v: DeliNode) =
  engine.evaluateStream(v).close


### Flow ###

proc doConditional(engine: Engine, cond: DeliNode) =
  #echo cond.repr

  let condition = cond.sons[0]
  let code = cond.sons[1]
  let top_line = -cond.line
  let end_line = -code.sons[^1].line

  if cond.node == nil:
    var jump_true  = DK(dkJump)
    var jump_false = DK(dkJump)
    var jump_end   = DK(dkJump)

    engine.insertStmt( DKInner( top_line, jump_true ) )
    jump_true.node = engine.writehead

    for stmt in code.sons:
      engine.insertStmt( stmt )

    engine.insertStmt( DKInner( end_line, jump_end ) )
    engine.insertStmt( DKInner( end_line, jump_false ) )
    jump_false.node = engine.writehead

    #engine.insertStmt( DKInner( top_line - 1, jump_end ) )
    jump_end.node = engine.writehead

    cond.sons.add(jump_true)
    cond.sons.add(jump_false)
    cond.node = jump_end.node

  debug 3:
    for stmt in engine.statements:
      if stmt.kind == dkInner:
        echo stmt.repr, stmt.line


  let jump_true  = cond.sons[^2]
  let jump_false = cond.sons[^1]

  let eval = engine.evaluate(condition)
  debug 3:
    echo "  condition: ", $eval
  let ok = engine.isTruthy(eval)

  if ok:
    engine.setHeads(jump_true.node)
  else:
    engine.setHeads(jump_false.node)

proc doDoLoop(engine: Engine, loop: DeliNode) =
  let code = loop.sons[0]
  let condition = loop.sons[1]
  let top_line = -loop.line
  let end_line = -code.sons[^1].line

  if loop.node == nil:
    var jump_break    = DK(dkJump)
    var jump_continue = DK(dkJump)

    engine.setupPush(top_line, {
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTable)

    jump_continue.node = engine.write_head
    engine.insertStmt(code.sons)

    engine.insertStmt( DKInner( -end_line + 1,
      DK( dkConditional, condition,
        DK( dkCode, DKInner( end_line - 1,
          DeliNode(kind: dkContinueStmt, line: end_line - 1)
        ))
      )
    ))

    jump_break.node = engine.writehead
    engine.setupPop( end_line - 1 )
    loop.node = jump_continue.node

  engine.debugNext()

proc doWhileLoop(engine: Engine, loop: DeliNode) =
  let condition = loop.sons[0]
  let code      = loop.sons[1]
  let top_line = -loop.line
  let end_line = -code.sons[^1].line

  if loop.node == nil:
    var jump_break    = DK(dkJump)
    var jump_continue = DK(dkJump)

    engine.setupPush(top_line, {
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTable)

    jump_continue.node = engine.write_head
    engine.insertStmt( DKInner( top_line,
      DK( dkConditional, DK( dkBoolNot, condition),
        DK( dkCode, DKInner( top_line,
          DeliNode(kind: dkBreakStmt, line: top_line)
        ))
      )
    ))
    engine.insertStmt(code.sons)

    engine.insertStmt( DKInner(end_line - 1,
      DK( dkContinueStmt )
    ))

    jump_break.node = engine.writehead
    engine.setupPop( end_line - 1 )

    loop.sons.add(jump_break)
    loop.sons.add(jump_continue)
    loop.node = jump_continue.node

  engine.debugNext()

proc doForLoop(engine: Engine, loop: DeliNode) =
  let variable = loop.sons[0]
  let things   = engine.evaluate(loop.sons[1])
  let code     = loop.sons[2]
  let top_line = -loop.line
  let end_line = -code.sons[^1].line
  let counter  = DKVar(".counter")

  if loop.node == nil:
    var jump_break    = DeliNode(kind: dkJump, line: end_line + 1)
    var jump_continue = DeliNode(kind: dkJump, line: end_line)

    engine.setupPush(top_line, {
      ".counter" : DKInt(0),
      ".break"   : jump_break,
      ".continue": jump_continue,
    }.toTable)

    jump_continue.node = engine.write_head
    engine.insertStmt( DKInner(top_line,
      DK( dkVariableStmt, variable, DK(dkAssignOp),
        DK( dkVarDeref, things, counter )
      ),
      DK( dkConditional,
        DK( dkComparison, DK(dkCompEq), deliNone(), variable ),
        DK( dkCode, DKInner( top_line,
          DeliNode(kind: dkBreakStmt, line: top_line)
        ))
      )
    ))

    engine.insertStmt(code.sons)

    engine.insertStmt( DKInner(end_line - 1,
      DK( dkVariableStmt, counter, DK(dkAppendOp), DKInt(1) ),
      DK( dkContinueStmt )
    ))

    jump_break.node = engine.writehead
    engine.setupPop( end_line - 1 )
    loop.node = jump_continue.node

  # unroll loop
  #let code = loop.sons[2]
  #for thing in things.sons:
  #  engine.insertStmt(deliLocalAssign(variable, thing, -loop.line))
  #  for stmt in code.sons:
  #    engine.insertStmt(stmt)

  engine.debugNext()


### Runtime ###

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
    engine.setHeads(s.node)
    engine.debugNext()
  of dkVariableStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkCloseStmt:
    engine.doClose(s.sons[0])
  of dkArgStmt:
    if s.sons[0].kind == dkVariable:
      var shifted = engine.shift()
      var value = if shifted.kind != dkNone:
        shifted
      elif nsons > 1: # DefaultOp ArgDefault Expr
        s.sons[2].sons[0]
      else:
        deliNone()
      engine.assignVariable(s.sons[0].varName, value)
    else:
      if nsons > 1:
        engine.doArg(s.sons[0].sons, s.sons[2].sons[0])
      else:
        engine.doArg(s.sons[0].sons, deliNone())
    engine.printVariables()
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
  of dkConditional:
    engine.doConditional(s)
  of dkForLoop:
    engine.doForLoop(s)
  of dkWhileLoop:
    engine.doWhileLoop(s)
  of dkDoLoop:
    engine.doDoLoop(s)
  of dkFunction:
    engine.doFunctionDef(s.sons[0], s.sons[1])
  of dkFunctionStmt:
    let call = s.sons[0]
    discard engine.evalFunctionCall(call.sons[0], call.sons[1 .. ^1])
  of dkContinueStmt:
    var to = engine.getVariable(".continue")
    engine.setHeads(to.node)
  of dkBreakStmt:
    var to = engine.getVariable(".break")
    engine.setHeads(to.node)
  of dkReturnStmt:
    var head_to = engine.getVariable(".return")
    if nsons > 0:
      discard engine.retvals.pop()
      engine.retvals.push( engine.evaluate(s.sons[0]) )
    engine.setHeads(head_to.node)
  of dkPush:
    engine.pushLocals()
  of dkPop:
    engine.popLocals()
  of dkStreamStmt:
    engine.doStream(s.sons)
  of dkIncludeStmt:
    if s.sons.len == 1:
      engine.doInclude(s.sons[0])
      s.sons.add(DKTrue)
  of dkInner:
    for s in s.sons:
      engine.doStmt(s)
  of dkRunStmt:
    discard engine.doRun(s)
  else:
    todo "doStmt ", s.kind

proc readCurrent(engine: Engine) =
  engine.current = engine.readhead.value

proc execCurrent(engine: Engine) =
  engine.doStmt(engine.current)

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
    engine.execCurrent()
    if engine.isEnd():
      break
    engine.advance()
