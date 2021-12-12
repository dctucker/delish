import std/tables
import os
import deliast
import strutils
import sequtils
import stacks
import deliargs
import deliparser

type
  Engine* = ref object
    arguments: seq[Argument]
    variables: Table[string, DeliNode]
    locals:    Stack[ Table[string, DeliNode] ]
    envars:    Table[string, string]
    functions: Table[string, DeliNode]
    parser:    Parser
    script:    DeliNode
    current:   DeliNode
    fds:       Table[int, File]

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
    return a

  return deliNone()

proc todo(msg: varargs[string, `$`]) =
  stderr.write("\27[33mTODO: ", msg.join(""), "\27[0m\n")

proc repr(node: DeliNode): string =
  result = ""
  result &= $node
  if node.sons.len() > 0:
    result &= "( "
    for n in node.sons:
      result &= repr(n)
    result &= ")"
  result &= " "

proc lineInfo*(engine: Engine, line: int): string =
  let sline = engine.parser.getLine(line)
  let linenum = "\27[1;30m:" & $line
  let source = " \27[0;34;4m" & sline
  let parsed = "\27[1;24m " & repr(engine.current)
  return linenum & source & parsed & "\27[0m"

proc newEngine*(parser: Parser): Engine =
  result = Engine(
    arguments: newSeq[Argument](),
    variables: initTable[string, DeliNode](),
    parser:    parser,
    script:    parser.getScript()
  )
  result.locals.push(initTable[string, DeliNode]())
  result.fds[0] = stdin
  result.fds[1] = stdout
  result.fds[2] = stderr

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
  echo "  argument to deref: ", $arg
  case arg.kind
  of dkArgShort:
    return findArgument(engine.arguments, Argument(short_name:arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name:arg.argName)).value
  else:
    todo "getArgument " & $(arg.kind)

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkBoolean, dkString, dkInteger, dkPath, dkStream, dkStrBlock, dkStrLiteral, dkNone:
    return val
  of dkArray:
    result = DeliNode(kind: dkArray)
    for son in val.sons:
      result.sons.add(engine.evaluate(son))
    return result
  of dkRunStmt:
    let ran = engine.doRun(val.sons)
    return ran
  of dkExpr:
    result = engine.evaluate(val.sons[0])
  of dkArg:
    let arg = engine.getArgument(val.sons[0])
    result = engine.evaluate(arg)
    echo $result
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
  echo engine.locals

proc assignVariable(engine: Engine, key: string, value: DeliNode) =
  if engine.locals.peek().contains(key):
    engine.assignLocal(key, value)
  elif engine.envars.contains(key):
    engine.assignEnvar(key, value.toString())
    engine.variables[key] = value
  else:
    engine.variables[key] = value
    engine.printVariables()

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, val: DeliNode) =
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
  echo "condition: ", eval
  let ok = engine.isTruthy(eval)
  if not ok: return
  for stmt in code.sons:
    engine.runStmt(stmt)

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
    engine.runStmt(s)
  engine.popLocals()

proc doLocal(engine: Engine, name: DeliNode, default: DeliNode) =
  var locals = engine.locals.pop()
  locals[name.varName] = default
  engine.locals.push(locals)

proc evaluateStream(engine: Engine, stream: DeliNode): File =
  #let num = if stream.sons.len() > 0:
  #  engine.variables[stream.sons[0].varName].intVal
  #else:
  #  stream.intVal
  let num = stream.intVal
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

proc doOpen(engine: Engine, nodes: seq[DeliNode]) =
  let variable = nodes[0]
  var mode = fmReadWrite
  for node in nodes[1 .. ^1]:
    case node.kind
    of dkStream:
      let mode = node.intVal
    of dkPath:
      let path = node.strVal
    else:
      discard
  engine.variables[variable.varName] = DeliNode(kind: dkStream, intVal: -1)
  todo "open file and assign file descriptor"

proc runStmt(engine: Engine, s: DeliNode) =
  engine.current = s
  if s.kind notin [dkStatement, dkBlock]:
    echo engine.lineInfo(s.line)
  let nsons = s.sons.len()
  case s.kind
  of dkStatement, dkBlock:
    engine.runStmt(s.sons[0])
  of dkAssignStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkArgStmt:
    if nsons > 1:
      engine.doArg(s.sons[0].sons, s.sons[1].sons[0])
    else:
      engine.doArg(s.sons[0].sons, deliNone())
  of dkEnvStmt:
    if nsons > 1:
      engine.doEnv(s.sons[0], s.sons[1])
    else:
      engine.doEnv(s.sons[0])
  of dkLocalStmt:
    if nsons > 1:
      engine.doLocal(s.sons[0], s.sons[1])
    else:
      engine.doLocal(s.sons[0], deliNone())
  of dkConditional:
    engine.doConditional(s.sons[0], s.sons[1])
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

iterator runStatements(engine: Engine, statements: seq[DeliNode]): int =
  for s in statements:
    #echo s.kind
    #printSons(s)
    #echo "\27[0m"
    if s.sons.len() > 0:
      for s2 in s.sons:
        yield s2.line
        engine.runStmt(s2)

iterator tick*(engine: Engine): int =
  echo "\nRunning program..."
  engine.initArguments()
  for line in runStatements(engine, engine.script.sons):
    yield line


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
