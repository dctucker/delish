import std/parseopt
import deliast

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

var user_args*: seq[Argument]

proc printUserArguments*() =
  echo "== User Arguments =="
  for arg in user_args:
    echo arg

proc initUserArguments*() =
  user_args = @[]
  for arg in parseCmdLine():
    user_args.add(arg)

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

