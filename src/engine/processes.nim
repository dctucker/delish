### Processes ###

proc doRun(engine: Engine, run: DeliNode): DeliNode =
  var args = newSeq[string]()
  for inv in run.sons[0].sons:
    args.add inv.toKind(dkString).strVal
  var p = newDeliProcess(args)
  result = p.ran

  try:
    p.start
  except OSError as e:
    p.exit = e.errorCode
    engine.runtimeError(e.msg)

  #TODO let i = engine.addFd(p.handles[0], p.streams[0])
  let o = engine.addFd(p.handles[1], p.streams[1])
  #TODO let e = engine.addFd(p.handles[2], p.streams[2])

  let output = engine.fds[o].stream.readAll()
  result.table["out"] = DKStr(output)

  p.wait
  p.close
