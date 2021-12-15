import std/parseopt
import deliast

type Argument* = ref object
  short_name*, long_name* : string
  value*: DeliNode

proc `$`*(arg: Argument): string =
  result = ""
  if arg.short_name != "":
    result &= " -" & arg.short_name
  if arg.long_name != "":
    result &= " --" & arg.long_name
  #if ( arg.short_name != "" or arg.long_name != "" ) and arg.value != nil:
  result &= " = "
  if arg.value != nil:
    result &= $(arg.value)

proc isNone*(arg: Argument):bool =
  return arg.short_name == "" and arg.long_name == "" and arg.value.isNone()

proc isFlag*(arg: Argument):bool =
  return arg.short_name != "" or arg.long_name != ""

proc strVal(s:string): DeliNode =
  return DeliNode(kind: dkString, strVal: s)

iterator parseCmdLine(): Argument =
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdLongOption:
      if p.val == "":
        yield Argument(long_name: p.key, value: deliNone())
      else:
        yield Argument(long_name: p.key, value: strVal p.val)
    of cmdShortOption:
      if p.val == "":
        yield Argument(short_name: p.key, value: deliNone())
      else:
        yield Argument(short_name: p.key, value: strval p.val)
    of cmdArgument:
      yield Argument(value: strval p.key)

#var params = commandLineParams()
#proc shift() =
#  params = params[1 .. ^1]

var user_args*: seq[Argument]

proc printUserArguments*() =
  echo "== User Arguments =="
  for arg in user_args:
    echo arg

proc initUserArguments*() =
  user_args = @[]
  for arg in parseCmdLine():
    user_args.add(arg)

proc shift*(): Argument =
  result = user_args[0]
  user_args = user_args[1 .. ^1]

proc matchNames(a, b: Argument): bool =
  if a.short_name != "" and a.short_name == b.short_name:
    return true
  if a.long_name != "" and a.long_name == b.long_name:
    return true
  return false

proc findArgument*(args: seq[Argument], a: Argument): Argument =
  #echo "searching for arg ", name
  for b in args:
    if not b.isFlag():
      continue
    if matchNames(a,b):
      return b
  return Argument(value: deliNone())

