import std/tables
import std/lists
import os
import deliast
import strutils
import sequtils
import stacks
import deliargs
import deliparser

type
  Engine* = ref object
    debug*:     bool
    arguments:  seq[Argument]
    variables:  DeliTable
    locals:     Stack[ DeliTable ]
    envars:     Table[string, string]
    functions:  DeliTable
    parser:     Parser
    script:     DeliNode
    current:    DeliNode
    fds:        Table[int, File]
    statements: DeliList
    readhead:   DeliListNode
    writehead:  DeliListNode
    returns:    Stack[ DeliListNode ]

proc debugn(engine: Engine, msg: varargs[string, `$`]) =
  if not engine.debug:
    return
  stdout.write("\27[30;1m")
  for m in msg:
    stdout.write(m)
proc debug(engine: Engine, msg: varargs[string, `$`]) =
  if not engine.debug:
    return
  debugn engine, msg
  stdout.write("\n\27[0m")

proc setHeads(engine: Engine, list: DeliListNode) =
  engine.readhead = list
  engine.writehead = engine.readhead


proc evaluate(engine: Engine, val: DeliNode): DeliNode

proc insertStmt(engine: Engine, node: DeliNode) =
  if node.kind in @[ dkStatement, dkBlock ]:
    for s in node.sons:
      engine.insertStmt(s)
    return

  var sw = engine.writehead.next
  let listnode = newSinglyLinkedNode[DeliNode](node)
  engine.writehead.next = listnode
  listnode.next = sw
  engine.writehead = listnode

proc `+`(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: a.intVal + b.intval)
    of dkString:
      return DeliNode(kind: dkString, strVal: a.strVal & b.strVal)
    of dkArray:
      result = DeliNode(kind: dkArray)
      for n in a.sons:
        result.sons.add(n)
      for n in b.sons:
        result.sons.add(n)
        return result
    else:
      return deliNone()

  case a.kind
  of dkArray:
    a.sons.add(b)
    return a
  else:
    todo "add ", a.kind, " + ", b.kind
    return a

  return deliNone()

proc repr(node: DeliNode): string =
  result = ""
  result &= $node
  if node.sons.len() > 0:
    result &= "( "
    for n in node.sons:
      result &= repr(n)
    result &= ")"
  result &= " "

proc getOneliner(node: DeliNode): string =
  case node.kind
  of dkVariableStmt:
    return "$" & node.sons[0].varName & " " & node.sons[1].toString() & " " & node.sons[2].toString()
  of dkJump:
    let line = if node.node == nil:
      "end"
    else:
      $(node.node.value.line)
    return "jump :" & line
  of dkConditional:
    return "if " & $(node.sons[0].repr) & $(node.sons[1].repr)
  else:
    return $(node.kind) & "?"

proc sourceLine*(engine: Engine, line: int): string =
  return engine.parser.getLine(line)

proc lineInfo*(engine: Engine, line: int): string =
  let sline = if line > 0:
    engine.parser.getLine(line)
  else:
    getOneliner(engine.current)
  let linenum = "\27[1;30m:" & $abs(line)
  let source = " \27[0;34;4m" & sline
  let parsed = "\27[1;24m " & repr(engine.current)
  return linenum & source & parsed & "\27[0m"

proc newEngine*(parser: Parser): Engine =
  result = Engine(
    arguments:  newSeq[Argument](),
    variables:  initTable[string, DeliNode](),
    parser:     parser,
    script:     parser.getScript(),
    statements: @[deliNone()].toSinglyLinkedList
  )
  result.locals.push(initTable[string, DeliNode]())
  result.fds[0] = stdin
  result.fds[1] = stdout
  result.fds[2] = stderr
  result.readhead  = result.statements.head
  result.writehead = result.statements.head

proc printSons(node: DeliNode): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= " " & $son
      if son.sons.len() > 0:
        result &= "("
        result &= printSons(son)
        result &= ") "

proc printSons(node: DeliNode, level: int): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= indent($son, 4*level)
      result &= printSons(son, level+1)

proc printValue(v: DeliNode): string =
  result = "\27[30;1m"
  if( v.sons.len() > 0 ):
    result &= "("
    result &= printSons(v)
    result &= ")"
  result &= "\27[0m"

proc printVariables(engine: Engine) =
  if not engine.debug: return
  echo "\27[36m== Engine Variables (", engine.variables.len(), ") =="
  for k,v in engine.variables:
    stdout.write("  $", k, " = ")
    stdout.write(printValue(v))
    stdout.write("\n")

proc printArguments(engine: Engine) =
  if not engine.debug: return
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

proc printEnvars(engine: Engine) =
  if not engine.debug: return
  debug engine, "ENV = ", $(engine.envars)
  #echo "--- available envars ---"
  #for k,v in envPairs():
  #  stdout.write(k, " ")
  #stdout.write("\n")

proc debugNext(engine: Engine) =
  if not engine.debug: return
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

proc DK(kind: DeliKind, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    sons.add(node)
  return DeliNode(kind: kind, sons: sons)

proc DeliObject(table: openArray[tuple[key: string, val: DeliNode]]): DeliNode =
  return DeliNode(kind: dkObject, table: table.toTable)

proc doRun(engine: Engine, pipes: seq[DeliNode]): DeliNode =
  todo "run and consume output"
  return DeliNode(kind: dkRan, table: {
    "out": DeliNode(kind: dkStream, intVal: 1),
    "err": DeliNode(kind: dkStream, intVal: 2),
  }.toTable)

proc getArgument(engine: Engine, arg: DeliNode): DeliNode =
  case arg.kind
  of dkArgShort:
    return findArgument(engine.arguments, Argument(short_name:arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name:arg.argName)).value
  else:
    todo "getArgument ", arg.kind

proc getVariable(engine: Engine, name: string): DeliNode =
  let locals = engine.locals.peek()
  if locals.contains(name):
    return locals[name]
  elif engine.variables.contains(name):
    return engine.variables[name]
  elif engine.envars.contains(name):
    return DeliNode(kind: dkString, strVal: engine.envars[name])
  else:
    raise newException( Exception, "Unknown variable: $" & name )

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
      let idx = engine.evaluate(son).intVal
      if idx < result.sons.len:
        result = result.sons[idx]
      else:
        result = deliNone()
    else:
      todo "evalVarDeref Variable using ", son.kind

proc evalExpression(engine: Engine, expr: DeliNode): DeliNode =
  result = expr
  while result.kind == dkExpr:
    let s = result.sons[0]
    #echo s.kind
    result = engine.evaluate(s)

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
  todo "open file and assign file descriptor"
  result = DeliNode(kind: dkStream, intVal: 1)
  engine.variables[variable] = result

proc `>=`(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal >= o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal >= o2.strVal
  else:
    todo ">= ", o1.kind, " ", o2.kind

proc `!=`(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal != o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal != o2.strVal
  of dkNone:
    return o2.kind != dkNone
  else:
    todo "!= ", o1.kind, " ", o2.kind

proc `==`(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal == o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal == o2.strVal
  of dkNone:
    return o2.kind == dkNone
  else:
    todo "== ", o1.kind, " ", o2.kind

proc doComparison(engine: Engine, op, v1, v2: DeliNode): DeliNode =
  #echo "compare ", v1, op, v2
  let val = case op.kind
  of dkCompEq: v1 == v2
  of dkCompNe: v1 != v2
  of dkCompGt: v1 >  v2
  of dkCompGe: v1 >= v2
  of dkCompLt: v1 <  v2
  of dkCompLe: v1 <= v2
  else:
    todo "doComparison ", $op
    false
  return DeliNode(kind: dkBoolean, boolVal: val)


proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkBoolean, dkString, dkInteger, dkPath, dkStrBlock, dkStrLiteral, dkNone:
    return val
  of dkStream:
    return engine.evaluate(val.sons[0])
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
  of dkLazy:
    return val.sons[0]
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
  of dkEnvDefault:
    return engine.evaluate(val.sons[0])
  of dkOpenExpr:
    return engine.doOpen(val.sons)
  of dkComparison:
    let v1 = engine.evaluate(val.sons[1])
    let v2 = engine.evaluate(val.sons[2])
    return engine.doComparison(val.sons[0], v1, v2)
  else:
    todo "evaluate ", val.kind
    return deliNone()

proc assignEnvar(engine: Engine, key: string, value: string) =
  putEnv(key, value)
  engine.envars[key] = value
  engine.printEnvars()

proc assignLocal(engine: Engine, key: string, value: DeliNode) =
  var locals = engine.locals.pop()
  locals[key] = value
  engine.locals.push(locals)
  debug engine, "  locals = ", $(engine.locals)

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
  debug engine, "$", key, " = ", printValue(value)

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
    let value = variable + val
    engine.assignVariable(key.varName, value)
  else:
    todo "assign ", op.kind

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

proc doEnv(engine: Engine, name: DeliNode, default: DeliNode = deliNone()) =
  let key = name.varName
  let def = if default.isNone():
    ""
  else:
    engine.evaluate(default).toString()
  let value = getEnv(key, def)
  engine.envars[ name.varName ] = value
  engine.printEnvars()

proc isTruthy(engine: Engine, node: DeliNode): bool =
  case node.kind
  of dkBoolean: return node.boolVal
  else:
    return false
  return false

proc runStmt(engine: Engine, s: DeliNode)

proc doConditional(engine: Engine, condition: DeliNode, code: DeliNode) =
  let eval = engine.evaluate(condition)
  debug engine, "  condition: ", $eval
  let ok = engine.isTruthy(eval)
  if not ok: return
  for stmt in code.sons:
    engine.insertStmt(stmt)
    engine.debugNext()

proc doFunctionDef(engine: Engine, id: DeliNode, code: DeliNode) =
  engine.functions[id.id] = code
  debug engine, "define ", engine.functions


proc pushLocals(engine: Engine) =
  engine.locals.push(engine.locals.peek())
  debug engine, "  push locals ", engine.locals

proc popLocals(engine: Engine) =
  discard engine.locals.pop()
  debug engine, "  pop locals ", engine.locals

proc doFunctionCall(engine: Engine, id: DeliNode, args: seq[DeliNode]) =
  let code = engine.functions[id.id]
  engine.pushLocals()
  for s in code.sons:
    engine.insertStmt(s)
  engine.popLocals()
  engine.debugNext()

proc doLocal(engine: Engine, name: DeliNode, default: DeliNode) =
  var locals = engine.locals.pop()
  locals[name.varName] = default
  engine.locals.push(locals)

proc evaluateStream(engine: Engine, stream: DeliNode): File =
  #let num = if stream.sons.len() > 0:
  #  engine.variables[stream.sons[0].varName].intVal
  #else:
  #  stream.intVal
  let num = engine.evaluate(stream).intVal
  if engine.fds.contains(num):
    return engine.fds[num]

proc doStream(engine: Engine, nodes: seq[DeliNode]) =
  var fd: File
  let first_node = nodes[0]
  if first_node.kind == dkVariable:
    let num = engine.variables[first_node.varName].intVal
    if engine.fds.contains(num):
      fd = engine.fds[num]
  elif first_node.kind == dkStream:
    fd = engine.evaluateStream(first_node)

  let last_node = nodes[^1]
  for expr in last_node.sons:
    let eval = engine.evaluate(expr)
    let str = eval.toString()
    fd.write(str, "\n")

proc deliLocalAssign(variable: string, value: DeliNode, line: int): DeliNode =
  result = DK(dkVariableStmt,
    DeliNode(kind: dkVariable, varName: variable),
    DeliNode(kind: dkAssignOp),
    DK(dkLazy, value)
  )
  result.line = line

proc doForLoop(engine: Engine, node: DeliNode) =
  let variable = node.sons[0].varName
  let things = engine.evaluate(node.sons[1])
  let after = engine.readhead.next
  let end_line = -node.sons[2].sons[^1].line

  node.counter = variable & ".counter"
  engine.assignLocal(node.counter, DeliNode(kind: dkInteger, intVal: 0))

  var setup = DK(dkVariableStmt,
    DeliNode(kind: dkVariable, varName: variable),
    DK(dkAssignOp),
    DeliNode(kind: dkInteger, intVal: 0)
  )
  var assign = DK(dkVariableStmt,
    DeliNode(kind: dkVariable, varName: variable),
    DK(dkAssignOp),
    DK(dkExpr, DK(dkVarDeref, things, DeliNode(kind: dkVariable, varName: node.counter) ) )
  )
  var test = DK(dkConditional,
    DK(dkExpr,
      DK( dkComparison, DK(dkCompEq), deliNone(), DeliNode(kind: dkVariable, varName: variable) )
    ),
    DK(dkCode, DeliNode(kind: dkJump, node: after, line: -node.line) )
  )
  var increment = DK(dkVariableStmt,
    DeliNode(kind: dkVariable, varName: node.counter),
    DK(dkAppendOp),
    DeliNode(kind: dkInteger, intVal: 1)
  )

  setup.line = -node.line
  assign.line = -node.line
  test.line = -node.line
  increment.line = end_line

  engine.insertStmt( setup )
  var jump = DeliNode(kind: dkJump, node: engine.write_head, line: end_line)
  engine.insertStmt( assign )
  engine.insertStmt( test )
  for stmt in node.sons[2].sons:
    engine.insertStmt(stmt)
  engine.insertStmt( increment )
  engine.insertStmt( jump )

  #let code = node.sons[2]
  #for thing in things.sons:
  #  engine.insertStmt(deliLocalAssign(variable, thing, -node.line))
  #  for stmt in code.sons:
  #    engine.insertStmt(stmt)
  engine.debugNext()

proc runStmt(engine: Engine, s: DeliNode) =
  let nsons = s.sons.len()
  case s.kind
  of dkStatement, dkBlock:
    for stmt in s.sons:
      engine.insertStmt(stmt)
    engine.debugNext()
  of dkJump:
    engine.setHeads(s.node)
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
    if nsons > 1:
      engine.doLocal(s.sons[0], s.sons[1])
    else:
      engine.doLocal(s.sons[0], deliNone())
  of dkConditional:
    engine.doConditional(s.sons[0], s.sons[1])
  of dkForLoop:
    engine.doForLoop(s)
  of dkFunction:
    engine.doFunctionDef(s.sons[0], s.sons[1])
  of dkFunctionStmt:
    engine.doFunctionCall(s.sons[0], s.sons[1 .. ^1])
  of dkStreamStmt:
    engine.doStream(s.sons)
  else:
    todo "run ", s.kind

proc runArgStmts(engine: Engine, node: DeliNode) =
  case node.kind
  of dkStatement:
    engine.runArgStmts(node.sons[0])
  of dkArgStmt:
    engine.runStmt(node)
  of dkCode:
    for son in node.sons:
      engine.runArgStmts(son)
  else:
    discard

proc initArguments(engine: Engine) =
  engine.arguments = @[]
  for stmt in engine.script.sons:
    engine.runArgStmts(stmt)

  engine.printArguments()
  debug engine, "checking user arguments"

  for arg in user_args:
    debug engine, arg
    if arg.isFlag():
      let f = findArgument(engine.arguments, arg)
      if f.isNone():
        raise newException(Exception, "Unknown argument: " & arg.long_name)
      else:
        if arg.value.isNone():
          arg.value = DeliNode(kind: dkBoolean, boolVal: true)
        f.value = arg.value

  if engine.debug: engine.printArguments()

proc loadScript(engine: Engine) =
  for s in engine.script.sons:
    for s2 in s.sons:
      engine.insertStmt(s2)
  debug engine, engine.statements
  engine.setHeads(engine.statements.head.next)

iterator tick*(engine: Engine): int =
  engine.initArguments()
  engine.loadScript()
  debug engine, "\nRunning program..."
  while true:
    engine.current = engine.readhead.value
    yield engine.current.line
    engine.runStmt(engine.current)
    if engine.readhead == nil or engine.readhead.next == nil:
      break
    engine.setHeads(engine.readhead.next)

  #for line in runStatements(engine, engine.script.sons):
  #  yield line


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
