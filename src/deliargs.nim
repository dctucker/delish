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
        yield Argument(long_name: p.key)
      else:
        yield Argument(long_name: p.key, value: strVal p.val)
    of cmdShortOption:
      if p.val == "":
        yield Argument(short_name: p.key)
      else:
        yield Argument(short_name: p.key, value: strval p.val)
    of cmdArgument:
      yield Argument(value: strval p.key)

var user_args*: seq[Argument]

proc initUserArguments*() =
  user_args = @[]
  for arg in parseCmdLine():
    user_args.add(arg)

  echo "== User Arguments =="
  for arg in user_args:
    echo arg

proc findArgument*(args: seq[Argument], name: string): Argument =
  #echo "searching for arg ", name
  for b in args:
    if b.short_name == name:
      #echo $b
      return b
    if b.long_name == name:
      #echo $b
      return b
  return Argument(value: deliNone())

