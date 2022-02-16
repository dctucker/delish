# investigate https://github.com/Vindaar/shell/blob/master/shell.nim

import osproc
import streams
import std/strutils
import std/base64
import std/tables
import std/sequtils
import nimgraphviz

import deliast

let icatargs = @["+kitten", "icat", "--align","left"]
proc icat(input: Stream): Process =
  let icat = try:
    startProcess("kitty", args=icatargs, options={poUsePath})
  except OSError:
    raise
  icat.inputStream.write(input.readAll())
  icat.inputStream.close()
  result = icat

proc rsvg(input: Stream): Process =
  let rsvg = try:
    startProcess("rsvg-convert", args=["-d144", "-p144"], options={poUsePath})
  except OSError:
    raise
  rsvg.inputStream.write(input.readAll())
  rsvg.inputStream.close()
  result = rsvg

let dotargs = @[
  "-Kdot",
  "-Tpng",
  "-s144",
  "-Grankdir=LR",
  "-Gbgcolor=transparent",
  "-Gcolor=lightgrey",
  "-Ncolor=gray40",
  "-Nfontcolor=#dddddd",
  "-Nfillcolor=#110844",
  "-Nstyle=filled",
  "-Nshape=Mrecord",
  "-Nfontname=Menlo",
  "-Nfontsize=10",
  "-Ecolor=#99aaff",
  "-Esplines=true",
]
proc dot(input: Stream, format: string = "png"): Process =
  let dot =
    try:
      startProcess("dot", args=dotargs, options={poUsePath})
    except OSError:
      raise
  dot.inputStream.write(input.readAll())
  dot.inputStream.close()
  result = dot

proc dot(graph: Graph): Process =
  let stream = newStringStream(graph.exportDot())
  return dot(stream)

proc nodeId(node: DeliNode): string =
  return $node.kind & $node.node_id

proc buildGraph(node: DeliNode, graph: Graph[Arrow] = nil): Graph[Arrow] =
  result = if graph == nil:
    newGraph[Arrow]()
  else:
    graph

  case node.kind
  of dkCode, dkBlock:
    let node_id = node_id(node)
    for son in node.sons:
      let son_id = node_id(son)
      graph.addEdge( node_id -> son_id )
      discard buildGraph(son, graph)
  else:
    discard

proc renderGraph(graph: Graph[Arrow]): string =
  let fout = open("output.data", fmWrite)
  #discard dup2(fout.getFileHandle())
  stdout = fout

  var procs: seq[Process] = @[]

  procs.add( graph.dot() )
  #procs.add( rsvg( procs[^1].outputStream ) )
  procs.add( icat( procs[^1].outputStream ) )

  for p in procs[0..^2]:
    stderr.write(p.errorStream.readAll())
    discard p.waitForExit()
    p.close()

  let p = procs[^1]
  let outp = outputStream(p)
  stderr.write(p.errorStream.readAll())
  discard p.waitForExit()
  p.close()
  fout.close()

proc serialize_gr_command(payload: string, cmd: var Table[string, string]): string =
  #cmd = ",".join(f'{k}={v}' for k, v in cmd.items())
  let params = cmd.pairs().toSeq().map(proc(p:(string, string)):string =
    p[0] & "=" & p[1]
  ).join(",")
  var ans: seq[string] = @[]
  ans.add("\27_G")
  ans.add(params)
  if payload.len > 0:
    ans.add(";")
    ans.add(payload)
  ans.add("\27\\")
  return ans.join("")

proc write_chunked(data: var string, cmd: var Table[string, string]) =
  #var data = encode(image)
  var remain = data.len()
  while remain > 0:
    remain = min( 4096, data.len() )
    let chunk = data[0..remain-1]
    data = data[remain..^1]
    let m = if remain < 4096: "0"
    else: "1"
    cmd["m"] = m
    stdout.write(serialize_gr_command(chunk, cmd))
    stdout.flushFile()
    cmd.clear()
    if remain < 4096: break
  stdout.write("\n")

when isMainModule:
  # create a directed graph
  let graph = newGraph[Arrow]()
  let sub = newGraph(graph)

  graph.addEdge("a"->"b", ("label", "A to B"))
  graph.addEdge("c"->"b", ("style", "dotted"))
  graph.addEdge("b"->"a")
  sub.addEdge("x"->"y")

  graph.addNode("c", ("color", "blue"),   ("shape", "box"),
                     ("style", "filled"), ("fontcolor", "white"))
  graph.addNode("d", ("label", "node 'd'"))

  #discard graph.renderGraph()
  #echo graph.exportDot()

  let cmd = "dot " & dotargs.join(" ") & " | base64"  # & " | kitty " & icatargs.join(" ")
  #echo cmd
  var b64png = execCmdEx(cmd, input = graph.exportDot()).output.strip()
  #stdout.write( png )
  var params = {"a": "T", "f": "100"}.toTable
  write_chunked(b64png, params)
  #discard execCmdEx("kitty " & icatargs.join(" "), input=png)
  #echo ""

