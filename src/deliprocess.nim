import std/paths
import std/osproc
import std/strtabs
import std/streams
import std/tables
import deliast

type
  DeliProcess* = object
    process : Process
    command*: string
    workdir*: string
    args*   : seq[string]
    env*    : StringTableRef
    id*     : int
    handles*: seq[FileHandle]
    streams*: seq[Stream]
    exit*   : int
    node*   : DeliNode

proc newDeliProcess*(args: seq[string]): DeliProcess =
  result.node = DKRan()

  result.command = args[0]
  result.workdir = $getCurrentDir()
  result.env = newStringTable()
  result.args = newSeq[string]()
  if args.len > 1:
    for arg in args[1..^1]:
      result.args.add arg

proc start*(p: var DeliProcess) =
  var flags = { poUsePath, poInteractive }
  #flags = flags + { poEchoCmd }
  p.process = startProcess(p.command, p.workdir, p.args, p.env, flags)
  p.handles.add p.process.inputHandle
  p.handles.add p.process.outputHandle
  p.handles.add p.process.errorHandle
  p.streams.add p.process.inputStream
  p.streams.add p.process.outputStream
  p.streams.add p.process.errorStream
  p.id = p.process.processID

  p.node.table["id"]  = DKInt(p.id)
  p.node.table["in"]  = DKStream(p.handles[0])
  p.node.table["out"] = DKStream(p.handles[1])
  p.node.table["err"] = DKStream(p.handles[2])

proc close*(p: var DeliProcess) =
  p.process.close

proc wait*(p: var DeliProcess) =
  p.exit = p.process.waitForExit
  p.node.table["exit"] = DKInt(p.exit)

