import std/tables
import std/lists
import os
import deliops
import deliast
import strutils
import sequtils
import stacks
import deliargs
import deliscript
import deliparser

type
  Engine* = ref object
    debug*:     int
    arguments:  seq[Argument]
    variables:  DeliTable
    locals:     Stack[ DeliTable ]
    envars:     Table[string, string]
    functions:  DeliTable
    current:    DeliNode
    fds:        Table[int, File]
    statements: DeliList
    readhead:   DeliListNode
    writehead:  DeliListNode
    returns:    Stack[ DeliListNode ]


proc evaluate(engine: Engine, val: DeliNode): DeliNode
proc doOpen(engine: Engine, nodes: seq[DeliNode]): DeliNode
proc doStmt(engine: Engine, s: DeliNode)
proc initArguments(engine: Engine, script: DeliNode)
proc initIncludes(engine: Engine, script: DeliNode)
proc loadScript(engine: Engine, script: DeliNode)


proc clearStatements*(engine: Engine) =
  engine.statements = @[deliNone()].toSinglyLinkedList

proc setup*(engine: Engine, script: DeliNode) =
  engine.initArguments(script)
  engine.initIncludes(script)
  engine.loadScript(script)

proc newEngine*(debug: int): Engine =
  result = Engine(
    arguments:  newSeq[Argument](),
    variables:  initTable[string, DeliNode](),
    statements: @[deliNone()].toSinglyLinkedList,
    current:    deliNone(),
    debug:      debug
  )
  result.clearStatements()
  result.locals.push(initTable[string, DeliNode]())
  result.fds[0] = stdin
  result.fds[1] = stdout
  result.fds[2] = stderr
  result.readhead  = result.statements.head
  result.writehead = result.statements.head

proc newEngine*(script: DeliNode, debug: int): Engine =
  result = newEngine(debug)
  result.setup(script)


### Engine ###

proc debugn(engine: Engine, msg: varargs[string, `$`]) =
  if engine.debug < 3: return
  stdout.write("\27[30;1m")
  for m in msg:
    stdout.write(m)
proc debug(engine: Engine, msg: varargs[string, `$`]) =
  if engine.debug < 3: return
  debugn engine, msg
  stdout.write("\n\27[0m")

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
  engine.insertStmt(DKInner(0, deliNone()))
  debug engine, engine.statements
  engine.setHeads(engine.statements.head.next)

proc sourceFile*(engine: Engine): string =
  result = ""
  if engine.current.script != nil:
    result = engine.current.script.filename

proc sourceLine*(engine: Engine): string =
  return engine.current.script.getLine( engine.current.line )

proc lineInfo*(engine: Engine): string =
  var filename: string
  var sline: string

  sline = getOneliner(engine.current)
  if engine.current.script != nil:
    filename = engine.current.script.filename
  let line = engine.current.line

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
  if engine.debug < 3: return
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
  stderr.write("\27[1;31m")
  stderr.write(msg)
  stderr.write("\n")
  quit(1)

### Environment ###

proc printEnvars(engine: Engine) =
  if engine.debug < 2: return
  debug engine, "ENV = ", $(engine.envars)
  #echo "--- available envars ---"
  #for k,v in envPairs():
  #  stdout.write(k, " ")
  #stdout.write("\n")

proc assignEnvar(engine: Engine, key: string, value: string) =
  putEnv(key, value)
  engine.envars[key] = value
  engine.printEnvars()

proc doEnv(engine: Engine, name: DeliNode, default: DeliNode = deliNone()) =
  let key = name.varName
  let def = if default.isNone():
    ""
  else:
    engine.evaluate(default).toString()
  let value = getEnv(key, def)
  engine.envars[ name.varName ] = value
  engine.printEnvars()


### Locals ###

proc printLocals(engine: Engine) =
  let layer = engine.locals.peek()
  if engine.debug < 2: return
  echo "\27[36m== Local Variables (", layer.len(), ") =="
  for k,v in layer:
    stdout.write("  $", k, " = ")
    stdout.write(printValue(v))
    stdout.write("\n")

proc pushLocals(engine: Engine) =
  engine.locals.push(engine.locals.peek())
  debug engine, "  push locals ", engine.locals

proc setupPush(engine: Engine, line: int, table: DeliTable) =
  var inner = DKInner(line, DK(dkPush))
  for k,v in table.pairs():
    inner.sons.add(DK(dkLocalStmt, DKVar(k), DK( dkAssignOp ), v))
  engine.insertStmt(inner)

proc popLocals(engine: Engine) =
  discard engine.locals.pop()
  debug engine, "  pop locals ", engine.locals

proc setupPop(engine: Engine, line: int) =
  engine.insertStmt( DKInner(line, DK(dkPop)) )

proc assignLocal(engine: Engine, key: string, value: DeliNode) =
  var locals = engine.locals.pop()
  locals[key] = value
  engine.locals.push(locals)
  debug engine, "  locals = ", $(engine.locals)

proc doLocal(engine: Engine, name: DeliNode, default: DeliNode) =
  var locals = engine.locals.pop()
  locals[name.varName] = engine.evaluate(default)
  engine.locals.push(locals)

#proc deliLocalAssign(variable: string, value: DeliNode, line: int): DeliNode =
#  result = DK(dkVariableStmt,
#    DKVar(variable),
#    DK(dkAssignOp),
#    DK(dkLazy, value)
#  )
#  result.line = line


### Variables ###

proc printVariables(engine: Engine) =
  if engine.debug < 2: return
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
    of dkObject:
      let str = son.toString()
      result = result.table[str]
    of dkArray:
      #echo engine.evaluate(son.repr).repr
      engine.printLocals()
      let idx = engine.evaluate(son).intVal
      if idx < result.sons.len:
        result = result.sons[idx]
      else:
        result = deliNone()
    else:
      todo "evalVarDeref ", result.kind, " using ", son.kind

proc assignVariable(engine: Engine, key: string, value: DeliNode) =
  engine.debugn "  "
  if engine.locals.peek().contains(key):
    engine.assignLocal(key, value)
    engine.debugn "local "
  elif engine.envars.contains(key):
    engine.assignEnvar(key, value.toString())
    engine.variables[key] = value
  else:
    engine.variables[key] = value
  debug engine, "$", key, " = ", value.kind, " ", printValue(value)

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, expr: DeliNode) =
  let val = if expr.kind == dkExpr:
      expr.sons[0]
    else:
      expr
  case op.kind
  of dkAssignOp:
    let value = engine.evaluate(val)
    engine.assignVariable(key.varName, value)
    #echo value
  of dkAppendOp:
    let variable = engine.getVariable(key.varName)
    let value = if val.kind == dkVarDeref:
      engine.evalVarDeref(val)
    else:
      val
    debug engine, variable, " += ", value.repr
    let out_value = variable + value
    engine.assignVariable(key.varName, out_value)
  of dkRemoveOp:
    let variable = engine.getVariable(key.varName)
    let value = if val.kind == dkVarDeref:
      engine.evalVarDeref(val)
    else:
      val
    debug engine, variable, " -= ", value.repr
    let out_value = variable - value
    engine.assignVariable(key.varName, out_value)
  else:
    todo "assign ", op.kind


### Arguments ###

proc printArguments(engine: Engine) =
  if engine.debug < 2: return
  echo "\27[36m== Engine Arguments =="
  let longest = engine.arguments.map(proc(x:Argument):int = x.long_name.len()).max()
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
    return findArgument(engine.arguments, Argument(short_name:arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name:arg.argName)).value
  else:
    todo "getArgument ", arg.kind

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
    engine.arguments.add(arg)
    #engine.printArguments()
    #echo "\n"

proc doIncludes(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkScript, dkCode, dkStatement:
    for n in node.sons:
      engine.doIncludes(n)
  of dkIncludeStmt:
    engine.doStmt(node)
  else:
    discard

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

proc initIncludes(engine: Engine, script: DeliNode) =
  engine.doIncludes(script)

proc initArguments(engine: Engine, script: DeliNode) =
  engine.arguments = @[]
  for stmt in script.sons:
    engine.doArgStmts(stmt)

  engine.printArguments()
  debug engine, "checking user arguments"

  for arg in user_args:
    debug engine, arg
    if arg.isFlag():
      let f = findArgument(engine.arguments, arg)
      if f.isNone():
        engine.runtimeError("Unknown argument: " & arg.long_name)
      else:
        if arg.value.isNone():
          arg.value = DeliNode(kind: dkBoolean, boolVal: true)
        f.value = arg.value

  if engine.debug > 2: engine.printArguments()


### Processes ###

proc doRun(engine: Engine, pipes: seq[DeliNode]): DeliNode =
  todo "run and consume output"
  return DeliNode(kind: dkRan, table: {
    "out": DeliNode(kind: dkStream, intVal: 1),
    "err": DeliNode(kind: dkStream, intVal: 2),
  }.toTable)


### Evaluation ###

proc isTruthy(engine: Engine, node: DeliNode): bool =
  case node.kind
  of dkBoolean: return node.boolVal
  else:
    return false
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

proc evalExpression(engine: Engine, expr: DeliNode): DeliNode =
  result = expr
  while result.kind == dkExpr:
    let s = result.sons[0]
    #echo s.kind
    result = engine.evaluate(s)

proc getStreamNumber(node: DeliNode): int =
  return node.intVal

proc evaluateStream(engine: Engine, stream: DeliNode): File =
  #let num = if stream.sons.len() > 0:
  #  engine.variables[stream.sons[0].varName].intVal
  #else:
  #  stream.intVal
  let num = engine.evaluate(stream).getStreamNumber()
  if engine.fds.contains(num):
    return engine.fds[num]

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkBoolean, dkString, dkInteger, dkPath, dkStrBlock, dkStrLiteral, dkJump, dkNone:
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
  of dkRunStmt:
    let ran = engine.doRun(val.sons)
    return ran
  of dkExpr:
    return engine.evalExpression(val)
  of dkVariable:
    return engine.getVariable(val.varName)
  of dkVarDeref:
    return engine.evalVarDeref(val)
  of dkArg:
    debugn engine, "  dereference ", val.sons[0]
    let arg = engine.getArgument(val.sons[0])
    result = engine.evaluate(arg)
    debug engine, " = ", $result
  of dkArgExpr:
    let arg = val.sons[0]
    let aval = engine.evalExpression(val.sons[1])
    result = DK(dkArray, arg, aval)
  of dkOpenExpr:
    return engine.doOpen(val.sons)
  of dkBoolNot:
    return not engine.evaluate( val.sons[0] )
  of dkComparison:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalComparison(val.sons[0], v1, v2)
  of dkMathExpr:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.evalMath(val.sons[0], v1, v2)
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
    engine.fds[num] = file
    result = DeliNode(kind: dkStream, intVal: num)
    engine.variables[variable] = result
  except IOError:
    engine.runtimeError("Unable to open: " & path)

proc doStream(engine: Engine, nodes: seq[DeliNode]) =
  var fd: File
  let first_node = nodes[0]
  if first_node.kind == dkVariable:
    let num = engine.variables[first_node.varName].getStreamNumber()
    if engine.fds.contains(num):
      fd = engine.fds[num]
  elif first_node.kind == dkStream:
    fd = engine.evaluateStream(first_node)

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
        let bytes = input.readChars(buffer)
        let written = fd.writeChars(buffer, 0, bytes)
        if written < bytes:
          todo "handle underrun"
        if bytes < buflen:
          break
      fd.flushFile()
    else:
      str = eval.toString()
      #echo str.repr
      fd.write(str, "\n")


### Functions ###

proc doFunctionDef(engine: Engine, id: DeliNode, code: DeliNode) =
  engine.functions[id.id] = code
  debug engine, "define ", engine.functions

proc doFunctionCall(engine: Engine, id: DeliNode, args: seq[DeliNode]) =
  let code = engine.functions[id.id]

  var jump_return = DeliNode(kind: dkJump, line: -code.sons[0].line + 1)
  engine.setupPush( -code.sons[0].line + 1, {
    ".return": jump_return
  }.toTable)

  for s in code.sons:
    engine.insertStmt(s)

  jump_return.node = engine.writehead
  engine.setupPop( -code.sons[^1].line - 1 )
  engine.debugNext()


### Flow ###

proc doConditional(engine: Engine, cond: DeliNode) =
  let condition = cond.sons[0]
  let code = cond.sons[1]
  let top_line = -cond.line
  let end_line = -code.sons[^1].line

  #echo cond.repr

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

  let jump_true  = cond.sons[2]
  let jump_false = cond.sons[3]

  let eval = engine.evaluate(condition)
  debug engine, "  condition: ", $eval
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
  of dkArgStmt:
    if nsons > 1:
      engine.doArg(s.sons[0].sons, s.sons[2].sons[0])
    else:
      engine.doArg(s.sons[0].sons, deliNone())
    engine.printVariables()
  of dkEnvStmt:
    if nsons > 1:
      engine.doEnv(s.sons[0], s.sons[2])
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
    engine.doFunctionCall(s.sons[0], s.sons[1 .. ^1])
  of dkContinueStmt:
    var to = engine.getVariable(".continue")
    engine.setHeads(to.node)
  of dkBreakStmt:
    var to = engine.getVariable(".break")
    engine.setHeads(to.node)
  of dkReturnStmt:
    var to = engine.getVariable(".return")
    engine.setHeads(to.node)
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
  else:
    todo "run ", s.kind

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
  debug engine, "\nRunning program..."
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

### do stuff with environment
#
#import std/os, sequtils
#when isMainModule:
#  stdout.write "$ "
#  var cmdline = readLine(stdin)
#
#  if cmdline == "glob":
#    let dir = toSeq(walkDir(".", relative=true))
#    for f in dir:
#      debug f

