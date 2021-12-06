
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
