import std/os

### Environment ###

proc printEnvars(engine: Engine) =
  debug 2:
    echo "ENV = ", $(engine.envars)
    #echo "--- available envars ---"
    #for k,v in envPairs():
    #  stdout.write(k, " ")
    #stdout.write("\n")

proc assignEnvar(engine: Engine, key: string, value: string) =
  putEnv(key, value)
  engine.envars[key] = value
  engine.printEnvars()

proc doEnv(engine: Engine, name: DeliNode, op: DeliKind = dkNone, default: DeliNode = deliNone()) =
  let key = name.varName
  let def = if default.isNone():
    ""
  else:
    engine.evaluate(default).toString()
  if op == dkAssignOp:
    putEnv(key, def)
  engine.envars[ name.varName ] = getEnv(key, def)
  engine.printEnvars()


