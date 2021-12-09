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
      return DeliNode(kind: dkArray, sons: concat(a.sons, b.sons))
    else:
      discard


proc newEngine*(): Engine =
  return Engine(
    arguments: newSeq[Argument](),
    variables: initTable[string, DeliNode]()
  )

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent(toString(son), 4*level)
    printSons(son, level+1)

proc printVariables(engine: Engine) =
  echo "Engine Variables:"
  for k,v in engine.variables:
    stdout.write("  $", k, " = ")
    printSons(v, 0)
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
  else:
    echo "Not implemented: evaluate ", val.kind

proc doAssign(engine: Engine, key: DeliNode, op: DeliNode, val: DeliNode) =
  case op.kind
  of dkAssignOp:
    engine.variables[key.varName] = engine.evaluate(val)
    engine.printVariables()
  of dkAppendOp:
    engine.variables[key.varName] = engine.variables[key.varName] + val
    engine.printVariables()
  else:
    echo "Not implemented: assign ", op.kind

proc doArg(engine: Engine, names: seq[DeliNode], val: DeliNode ) =
  let arg = Argument()
  for name in names:
    case name.sons[0].kind
    of dkArgShort:
      arg.short_name = name.sons[0].argName
    of dkArgLong:
      arg.long_name = name.sons[0].argName
    else:
      echo "Not implemented: arg ", name.sons[0].kind
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
    echo "Not implemented: run ", s.kind



proc runProgram*(engine: Engine, script: DeliNode) =
  echo "\nRunning program..."
  for s in script.sons:
    printSons(s, 0)
    echo s[]
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
