import std/tables
import deliast
import strutils
import sequtils
import deliargs

type
  Engine* = ref object
    arguments: seq[Argument]
    variables: Table[string, DeliNode]

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
  echo "\27[33mTODO: ", msg.join(""), "\27[0m"


proc newEngine*(): Engine =
  return Engine(
    arguments: newSeq[Argument](),
    variables: initTable[string, DeliNode]()
  )

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
    stdout.write( v, "(" )
    printSons(v)
    stdout.write( ")" )
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

proc initArguments(engine: Engine) =
  initUserArguments()
  engine.arguments = @[]

proc getArgument(engine: Engine, arg: DeliNode): DeliNode =
  echo "  argument to deref: ", $arg
  return findArgument(engine.arguments, arg.argName).value

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkBoolean, dkString, dkInteger, dkPath, dkStream, dkStrBlock:
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
  else:
    todo "evaluate ", val.kind
    return deliNone()

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, val: DeliNode) =
  case op.kind
  of dkAssignOp:
    engine.variables[key.varName] = engine.evaluate(val)
    engine.printVariables()
  of dkAppendOp:
    engine.variables[key.varName] = engine.variables[key.varName] + val
    engine.printVariables()
  else:
    todo "assign ", op.kind

proc doArg(engine: Engine, names: seq[DeliNode], default: DeliNode ) =
  let arg = Argument()
  for name in names:
    case name.sons[0].kind
    of dkArgShort:
      arg.short_name = name.sons[0].argName
    of dkArgLong:
      arg.long_name = name.sons[0].argName
    else:
      todo "arg ", name.sons[0].kind

  let user_arg = findArgument(user_args, names[0].sons[0].argName)
  if user_arg.value == nil:
    arg.value = DeliNode(kind: dkBoolean, boolVal: true)
  elif user_arg.value.kind == dkNone:
    arg.value = engine.evaluate(default)
  else:
    arg.value = user_arg.value
  echo "arg value = ", $(arg.value)

  engine.arguments.add(arg)
  engine.printArguments()

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

proc runStmt(engine: Engine, s: DeliNode) =
  case s.kind
  of dkStatement, dkBlock:
    engine.runStmt(s.sons[0])
  of dkAssignStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkArgStmt:
    engine.doArg(s.sons[0].sons, s.sons[1].sons[0])
  of dkConditional:
    engine.doConditional(s.sons[0], s.sons[1])
  else:
    todo "run ", s.kind

iterator tick*(engine: Engine, script: DeliNode): int =
  echo "\nRunning program..."
  engine.initArguments()
  for s in script.sons:
    yield s.line
    printSons(s)
    echo "\27[0m"
    if s.sons.len() > 0:
      engine.runStmt(s.sons[0])

proc runProgram*(engine: Engine, script: DeliNode) =
  echo "\nRunning program..."
  engine.initArguments()
  for s in script.sons:
    stdout.write(":", s.line, " ", s)
    printSons(s)
    echo ""
    if s.sons.len() > 0:
      engine.runStmt(s.sons[0])

### do stuff with environment
#
#import std/os, sequtils
#when isMainModule:
#  stdout.write "$ "
#  var cmdline = readLine(stdin)
#
#  if cmdline == "envars":
#    for k,v in envPairs():
#      stdout.write(k, " ")
#    stdout.write("\n")
#
#  if cmdline == "glob":
#    let dir = toSeq(walkDir(".", relative=true))
#    for f in dir:
#      echo f
#
#
