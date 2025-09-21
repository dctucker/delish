template shift*() =
  if arg_i >= nodes.len:
    raise newException(ValueError, "missing argument; args: " & $nodes)
  arg = nodes[arg_i]
  arg_i += 1

template expect*(k) =
  if arg.kind != k:
    raise newException(ValueError, "expected " & k.name & ", not " & arg.kind.name)

template maxarg*() =
  if nodes.len > arg_i:
    raise newException(ValueError, "too many arguments: " & $nodes)
