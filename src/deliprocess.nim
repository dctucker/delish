import std/paths
import std/osproc
import std/strtabs

type
  DeliProcess* = object
    process:  Process
    command*:  string
    workdir*:  string
    args*:  seq[string]
    env*:   StringTableRef
    id*: int
    fds*: seq[FileHandle]
    exit*: int

proc newDeliProcess*(args: seq[string]): DeliProcess =
  result.command = args[0]
  result.workdir = $getCurrentDir()
  result.env = newStringTable()
  result.args = newSeq[string]()
  if args.len > 1:
    for arg in args[1..^1]:
      result.args.add arg

proc start*(p: var DeliProcess) =
  p.process = startProcess(p.command, p.workdir, p.args, p.env, { poUsePath, poInteractive, poEchoCmd })
  p.fds.add p.process.inputHandle
  p.fds.add p.process.outputHandle
  p.fds.add p.process.errorHandle
  p.id = p.process.processID

proc close*(p: var DeliProcess) =
  p.process.close

proc wait*(p: var DeliProcess) =
  p.exit = p.process.waitForExit
