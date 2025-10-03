### Arguments ###

proc arguments(engine: Engine): seq[Argument] =
  engine.argstack.peekUnsafe

proc addArgument(engine: Engine, arg: Argument) =
  engine.argstack.peekUnsafe.add(arg)

proc printArguments(engine: Engine) =
  debug 2:
    echo "\27[36m== Engine Arguments =="
    if engine.arguments.len == 0:
      stdout.write("(none)\27[0m\n")
      return
    let longest = engine.arguments.map(proc(x:Argument):int =
      x.long_name.len()
    ).max()
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
    stdout.write("\27[0m")

proc getArgument(engine: Engine, arg: DeliNode): DeliNode =
  case arg.kind
  of dkArgShort:
    return findArgument(engine.arguments, Argument(short_name: arg.argName)).value
  of dkArgLong:
    return findArgument(engine.arguments, Argument(long_name: arg.argName)).value
  else:
    todo "getArgument ", arg.kind

proc shift(engine: Engine): DeliNode =
  if engine.argstack.len == 1:
    result = nth(engine.argnum)
  else:
    let args = engine.getVariable(".args")
    result = args.sons[engine.argnum - 1]
  inc engine.argnum

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
    engine.addArgument(arg)
    #engine.printArguments()
    #echo "\n"

proc doArgStmts(engine: Engine, node: DeliNode) =
  case node.kind
  of dkStatement:
    engine.doArgStmts(node.sons[0])
  of dkArgStmt:
    engine.doStmt(node)
  of dkCode:
    for son in node.sons:
      engine.doArgStmts(son)
  else:
    discard

proc initArguments(engine: Engine, script: DeliNode) =
  for stmt in script.sons:
    engine.doArgStmts(stmt)
  engine.argnum = 1

  engine.printArguments()
  debug 3:
    echo "checking user arguments"

  for arg in user_args:
    debug 3:
      echo arg
    if arg.isFlag():
      let f = findArgument(engine.arguments, arg)
      if f.isNone():
        engine.setupError("Unknown argument: " & arg.long_name)
      else:
        if arg.value.isNone():
          arg.value = DeliNode(kind: dkBoolean, boolVal: true)
        f.value = arg.value
  debug 3:
    engine.printArguments()
