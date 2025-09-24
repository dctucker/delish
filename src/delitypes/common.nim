import ../language/ast

template shift*() =
  if arg_i >= nodes.len:
    raise newException(ValueError, "missing argument; args: " & $nodes)
  arg = nodes[arg_i]
  arg_i += 1

template expect*(k) =
  if arg.kind != k:
    raise newException(ValueError, "expected " & k.name & ", not " & arg.kind.name)

template nextarg*(k: static[DeliKind]) =
  shift
  expect k

template maxarg*() =
  if nodes.len > arg_i:
    raise newException(ValueError, "too many arguments: " & $nodes)

template argvars*() =
  var arg_i {.inject.}: int = 0
  var arg {.inject.}: DeliNode

template noargs*() =
  if nodes.len > 0:
    raise newException(ValueError, "too many arguments: " & $nodes)

export ast
