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
    arguments:  seq[Argument]
    variables:  Table[string, DeliNode]
    locals:     Stack[ Table[string, DeliNode] ]
    envars:     Table[string, string]
    functions:  Table[string, DeliNode]
    parser:     Parser
    script:     DeliNode
    current:    DeliNode
    fds:        Table[int, File]
    statements: SinglyLinkedList[DeliNode]
    readhead:   SinglyLinkedNode[DeliNode]
    writehead:  SinglyLinkedNode[DeliNode]

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
    todo "add " & $(a.kind) & " + " & $(b.kind)
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
  of dkAssignStmt:
    return "$" & node.sons[0].varName & " <- " & node.sons[2].toString()
  else:
    return $(node.kind) & "?"

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

proc printSons(node: DeliNode) =
  #stdout.write( ($(node.kind)).substr(2), " " )
  if node.sons.len() > 0:
    for son in node.sons:
      stdout.write( " ", son )
      if son.sons.len() > 0:
        stdout.write("(")
        printSons(son)
        stdout.write(") ")
      #stdout.write(",")

proc printSons(node: DeliNode, level: int) =
  if node.sons.len() > 0:
    for son in node.sons:
      echo indent($son, 4*level)
      printSons(son, level+1)

proc printVariables(engine: Engine) =
  echo "== Engine Variables (", engine.variables.len(), ") =="
  for k,v in engine.variables:
    stdout.write("  $", k, " = ")
    stdout.write( v)
    if( v.sons.len() > 0 ):
      stdout.write("(")
      printSons(v)
      stdout.write(")")
    echo ""

proc printArguments(engine: Engine) =
  echo "== Engine Arguments =="
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

proc printEnvars(engine: Engine) =
  echo "ENV = ", engine.envars
  #echo "--- available envars ---"
  #for k,v in envPairs():
  #  stdout.write(k, " ")
  #stdout.write("\n")

proc printNext(engine: Engine) =
  stdout.write("  next = ")
  var head = engine.readhead.next
  while head != nil:
    stdout.write(head.value.line, " ")
    head = head.next
  stdout.write("\n")

proc doRun(engine: Engine, pipes: seq[DeliNode]): DeliNode =
  todo "run and consume output"
  return DeliNode(kind: dkRan, sons: @[
    DeliNode(kind: dkObject, table: {
      "out": DeliNode(kind: dkStream, intVal: 1, sons: @[
      ]),
      "err": DeliNode(kind: dkStream, intVal: 2, sons: @[
      ])
    }.toTable())
  ])

proc getArgument(engine: Engine, arg: DeliNode): DeliNode =
  case arg.kind
  of dkArgShort:
    return findArgument(engine.arguments, Argument(short_name:arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name:arg.argName)).value
  else:
    todo "getArgument " & $(arg.kind)

proc getVariable(engine: Engine, name: string): DeliNode =
  let locals = engine.locals.peek()
  if locals.contains(name):
    return locals[name]
  elif engine.variables.contains(name):
    return engine.variables[name]

proc evalVarDeref(engine: Engine, vard: DeliNode): DeliNode =
  let variable = vard.sons[0]
  result = engine.getVariable(variable.varName)
  for son in vard.sons[1 .. ^1]:
    case result.kind
    of dkObject:
      let str = son.toString()
      result = result.table[str]
    of dkArray:
      let idx = engine.evaluate(son).intVal
      result = result.sons[idx]
    else:
      todo "evalVarDeref using " & $(son.kind)

proc evalExpression(engine: Engine, expr: DeliNode): DeliNode =
  result = expr
  while result.kind == dkExpr:
    result = engine.evaluate(result.sons[0])

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
  of dkVarDeref:
    result = engine.evalVarDeref(val)
  of dkArg:
    stdout.write("  dereference ", $(val.sons[0]))
    let arg = engine.getArgument(val.sons[0])
    result = engine.evaluate(arg)
    stdout.write(" = ")
    echo $result
  of dkArgExpr:
    let arg = val.sons[0]
    let aval = engine.evalExpression(val.sons[1])
    result = DeliNode(kind: dkArray, sons: @[arg, aval])
  of dkEnvDefault:
    return engine.evaluate(val.sons[0])
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
  echo "  locals = ", engine.locals

proc assignVariable(engine: Engine, key: string, value: DeliNode) =
  if engine.locals.peek().contains(key):
    engine.assignLocal(key, value)
  elif engine.envars.contains(key):
    engine.assignEnvar(key, value.toString())
    engine.variables[key] = value
  else:
    engine.variables[key] = value
    engine.printVariables()

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, expr: DeliNode) =
  let val = if expr.kind == dkExpr:
      expr.sons[0]
    else:
      expr
  case op.kind
  of dkAssignOp:
    engine.assignVariable(key.varName, engine.evaluate(val))
  of dkAppendOp:
    engine.assignVariable(key.varName, engine.variables[key.varName] + val)
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
  echo "  condition: ", eval
  let ok = engine.isTruthy(eval)
  if not ok: return
  for stmt in code.sons:
    engine.insertStmt(stmt)
    engine.printNext()

proc doFunctionDef(engine: Engine, id: DeliNode, code: DeliNode) =
  engine.functions[id.id] = code
  echo "define ", engine.functions


proc pushLocals(engine: Engine) =
  engine.locals.push(engine.locals.peek())
  echo "  push locals ", engine.locals

proc popLocals(engine: Engine) =
  discard engine.locals.pop()
  echo "  pop locals ", engine.locals

proc doFunctionCall(engine: Engine, id: DeliNode, args: seq[DeliNode]) =
  let code = engine.functions[id.id]
  engine.pushLocals()
  for s in code.sons:
    engine.insertStmt(s)
  engine.popLocals()
  engine.printNext()

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
  var expr_pos = 1
  var fd: File
  if nodes[0].kind == dkVariable:
    let num = engine.variables[nodes[0].varName].intVal
    if engine.fds.contains(num):
      fd = engine.fds[num]
    expr_pos = 2
  elif nodes[0].kind == dkStream:
    fd = engine.evaluateStream(nodes[0])

  for expr in nodes[expr_pos].sons:
    fd.write(engine.evaluate(expr).toString(), "\n")

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
    todo "redir open mode " & $(node.kind)

proc doOpen(engine: Engine, nodes: seq[DeliNode]) =
  let variable = nodes[0]
  var mode = fmReadWrite
  var path: string
  for node in nodes[1 .. ^1]:
    case node.kind
    of dkPath:
      path = node.strVal
    of dkRedirOp:
      mode = getRedirOpenMode(node.sons[0])
    else:
      todo "open " & $(node.kind)
  engine.variables[variable.varName] = DeliNode(kind: dkStream, intVal: 1)
  todo "open file and assign file descriptor"

proc deliLocalAssign(variable: string, value: DeliNode, line: int): DeliNode =
  result = DeliNode(kind: dkAssignStmt, line: line, sons: @[
    DeliNode(kind: dkVariable, varName: variable),
    DeliNode(kind: dkAssignOp),
    value
  ])

proc doForLoop(engine: Engine, node: DeliNode) =
  let variable = node.sons[0].varName
  let things = engine.evaluate(node.sons[1])
  let code = node.sons[2]
  for thing in things.sons:
    engine.insertStmt(deliLocalAssign(variable, thing, -node.line))
    for stmt in code.sons:
      engine.insertStmt(stmt)
  engine.printNext()

proc runStmt(engine: Engine, s: DeliNode) =
  let nsons = s.sons.len()
  case s.kind
  of dkStatement, dkBlock:
    for stmt in s.sons:
      engine.insertStmt(stmt)
    engine.printNext()
  of dkAssignStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkArgStmt:
    if nsons > 1:
      engine.doArg(s.sons[0].sons, s.sons[2].sons[0])
    else:
      engine.doArg(s.sons[0].sons, deliNone())
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
  of dkOpenStmt:
    engine.doOpen(s.sons)
  else:
    todo "run ", s.kind

proc runArgStmts(engine: Engine, node: DeliNode) =
  case node.kind
  of dkStatement:
    engine.runArgStmts(node.sons[0])
  of dkArgStmt:
    engine.runStmt(node)
  else:
    discard

proc initArguments(engine: Engine) =
  engine.arguments = @[]
  for stmt in engine.script.sons:
    engine.runArgStmts(stmt)

  initUserArguments()
  #engine.printArguments()
  #echo "checking user arguments"

  for arg in user_args:
    #echo arg
    if arg.isFlag():
      let f = findArgument(engine.arguments, arg)
      if f.isNone():
        raise newException(Exception, "Unknown argument: " & arg.long_name)
      else:
        if arg.value.isNone():
          arg.value = DeliNode(kind: dkBoolean, boolVal: true)
        f.value = arg.value

  engine.printArguments()

proc loadScript(engine: Engine) =
  for s in engine.script.sons:
    for s2 in s.sons:
      engine.insertStmt(s2)
  echo $(engine.statements)
  engine.readhead = engine.statements.head.next
  engine.writehead = engine.readhead

iterator tick*(engine: Engine): int =
  engine.initArguments()
  engine.loadScript()
  echo "\nRunning program..."
  while true:
    engine.current = engine.readhead.value
    yield engine.current.line
    engine.runStmt(engine.current)
    if engine.readhead.next == nil:
      break
    engine.readhead = engine.readhead.next
    engine.writehead = engine.readhead

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
#      echo f
