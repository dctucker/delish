import deliast

type
  Argument = ref object
    short_name, long_name : string
    value: string
  Engine* = object
    arguments: seq[Argument]

proc addArgument*(engine: Engine, sn = "", ln = "", v = "") =
  let arg = Argument(short_name: sn, long_name: ln, value: v)
  echo arg[]
  var args = engine.arguments
  args.add(arg)

proc newEngine*(): Engine =
  return Engine(arguments: newSeq[Argument](5))

proc runProgram*(engine: Engine, script: DeliNode) =
  for s in script.sons:
    echo s[]
    case s.kind
    of dkArgStmt:
      var sn = ""
      var ln = ""
      var dv = ""
      if s.short_name.kind == dkArg:
        sn = s.short_name.argName
      if s.long_name.kind == dkArg:
        ln = s.long_name.argName
      dv = case s.default_value.kind
      of dkString:
        s.default_value.strVal
      of dkInteger:
        $(s.default_value.intVal)
      of dkBoolean:
        $(s.default_value.boolVal)
      else:
        $s.default_value.kind

      engine.addArgument(sn, ln, dv)
    of dkIncludeStmt:
      echo s.includeVal.strVal
      #engine.addInclude(s.includeVal)
    of dkFunctionStmt:
      echo s.funcName.id
    else:
      echo $(s.kind)


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
