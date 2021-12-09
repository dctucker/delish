import std/tables
import deliast
import sequtils
import strutils

type
  Argument = ref object
    short_name, long_name : string
    value: DeliNode
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
      stdout.write( " ", toString(son) )
      if son.sons.len() > 0:
        stdout.write("(")
        printSons(son)
        stdout.write(") ")
      #stdout.write(",")

proc printSons(node: DeliNode, level: int) =
  if node.sons.len() > 0:
    for son in node.sons:
      echo indent(toString(son), 4*level)
      printSons(son, level+1)

proc printVariables(engine: Engine) =
  echo "Engine Variables: (", engine.variables.len(), ")"
  for k,v in engine.variables:
    stdout.write("  $", k, " = ")
    stdout.write( toString(v), "(" )
    printSons(v)
    stdout.write( ")" )
    echo ""

proc printArguments(engine: Engine) =
  for arg in engine.arguments:
    stdout.write("-", arg.short_name, " ", arg.long_name, " = ")
    printSons(arg.value, 0)

proc doRun(engine: Engine, pipes: seq[DeliNode]): DeliNode =
  return DeliNode(kind: dkRan)
  #, sons: [
  #  DeliNode(kind: dkObject, sons: [
  #    DeliNode(kind: dkExpr
  #    DeliNode(kind: dkStream, intVal: 1)
  #    DeliNode(kind: dkStream, intVal: 2)
  #]])

proc evaluate(engine: Engine, val: DeliNode): DeliNode =
  case val.kind
  of dkRunStmt:
    let ran = engine.doRun(val.sons)
    result = DeliNode(kind: dkRan)
    result.sons.add(ran)
  of dkExpr:
    result = val.sons[0]
  else:
    todo "evaluate ", val.kind

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

proc doArg(engine: Engine, names: seq[DeliNode], val: DeliNode ) =
  let arg = Argument()
  for name in names:
    case name.sons[0].kind
    of dkArgShort:
      arg.short_name = name.sons[0].argName
    of dkArgLong:
      arg.long_name = name.sons[0].argName
    else:
      todo "arg ", name.sons[0].kind
  arg.value = val
  engine.arguments.add(arg)
  engine.printArguments()

proc runStmt(engine: Engine, s: DeliNode) =
  case s.kind
  of dkAssignStmt:
    engine.doAssign(s.sons[0], s.sons[1], s.sons[2])
  of dkArgStmt:
    engine.doArg(s.sons[0].sons, s.sons[1])
  else:
    todo "run ", s.kind

iterator tick*(engine: Engine, script: DeliNode): int =
  echo "\nRunning program..."
  for s in script.sons:
    yield s.line
    printSons(s)
    echo "\27[0m"
    if s.sons.len() > 0:
      engine.runStmt(s.sons[0])

proc runProgram*(engine: Engine, script: DeliNode) =
  echo "\nRunning program..."
  for s in script.sons:
    stdout.write(":", s.line, " ")
    printSons(s)
    echo ""
    if s.sons.len() > 0:
      engine.runStmt(s.sons[0])
    #case s.kind
    #of dkIncludeStmt:
    #  echo s.includeVal.strVal
    #  #engine.addInclude(s.includeVal)
    #of dkFunctionStmt:
    #  echo s.funcName.id
    #else:
    #  echo $(s.kind)


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
