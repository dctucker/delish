### File I/O

proc evaluateStream(engine: Engine, stream: DeliNode): FileDesc

proc initFd(file: File): FileDesc =
  FileDesc(
    file: file,
    stream: newFileStream(file),
    handle: file.getOsFileHandle(),
  )

proc initFd(handle: FileHandle, stream: Stream): FileDesc =
  FileDesc(
    file: nil,
    stream: stream,
    handle: handle,
  )

proc addFd(engine: Engine, handle: FileHandle, stream: Stream): int =
  result = cint handle
  engine.fds[result] = initFd(handle, stream)

proc getRedirOpenMode(node: DeliNode): FileMode =
  case node.kind
  of dkRedirReadOp:
    return fmRead
  of dkRedirWriteOp:
    return fmWrite
  of dkRedirAppendOp:
    return fmAppend
  of dkRedirDuplexOp:
    return fmReadWrite
  else:
    todo "redir open mode ", node.kind

proc doOpen(engine: Engine, nodes: seq[DeliNode]): DeliNode =
  result = deliNone()
  var variable: string
  var mode = fmReadWrite
  var path: string
  for node in nodes[0 .. ^1]:
    case node.kind
    of dkVariable:
      variable = node.varName
    of dkPath:
      path = node.strVal
    of dkRedirOper:
      mode = getRedirOpenMode(node.sons[0])
    else:
      todo "open ", node.kind
  try:
    let file = open(path, mode)
    let num = file.getOsFileHandle()
    engine.fds[num] = initFd(file)
    result = DKStream(num)
    engine.variables[variable] = result
  except IOError:
    engine.runtimeError("Unable to open: " & path)

proc doStream(engine: Engine, nodes: seq[DeliNode]) =
  var fd: FileDesc
  #for node in nodes: todo "doStream " & $node.kind
  let first_node = nodes[0]
  if first_node.kind == dkVariable:
    let num = engine.variables[first_node.varName].getStreamNumber()
    if engine.fds.contains(num):
      fd = engine.fds[num]
    else:
      engine.runtimeError("stream " & $num & " does not exist")
  elif first_node.kind == dkStream:
    fd = engine.evaluateStream(first_node)
  else:
    todo "doStream first_node " & $first_node.kind

  var str: string
  let last_node = nodes[^1]
  for expr in last_node.sons:
    #echo expr.repr
    let eval = engine.evaluate(expr)
    #echo eval.repr
    case eval.kind
    of dkStream:
      let input = engine.fds[eval.intVal]
      const buflen = 4096
      var buffer: array[buflen,char]
      while true:
        let bytes = input.file.readChars(buffer)
        let written = fd.file.writeChars(buffer, 0, bytes)
        if written < bytes:
          todo "handle underrun"
        if bytes < buflen:
          break
      fd.file.flushFile()
    else:
      #todo "doStream last_node " & $eval.kind
      str = eval.toString()
      #echo str.repr
      fd.file.write(str)
      #if i < last_node.sons.len - 1:
      #  fd.file.write(" ")
  fd.file.write("\n")

proc close(fd: FileDesc) =
  fd.stream.flush
  fd.stream.close

proc doClose(engine: Engine, v: DeliNode) =
  engine.evaluateStream(v).close
