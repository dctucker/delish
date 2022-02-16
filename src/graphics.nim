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
  #"-s144",
  "-Gdpi=72",
  "-Grankdir=LR",
  "-Gbgcolor=transparent",
  "-Gcolor=lightgrey",
  "-Ncolor=gray40",
  "-Nfontcolor=#dddddd",
  "-Nfillcolor=#110844",
  "-Nstyle=filled",
  "-Nshape=Mrecord",
  "-Nfontname=Menlo",
  "-Nfontsize=14",
  "-Ecolor=#99aaff",
  "-Esplines=true",
  "-q3",
]
#proc dot(input: Stream, format: string = "png"): Process =
#  let dot =
#    try:
#      startProcess("dot", args=dotargs, options={poUsePath})
#    except OSError:
#      raise
#  dot.inputStream.write(input.readAll())
#  dot.inputStream.close()
#  result = dot
#
#proc dot(graph: Graph): Process =
#  let stream = newStringStream(graph.exportDot())
#  return dot(stream)

proc nodeId(node: DeliNode): string =
  return $node.kind & $node.node_id

proc basicLabel(node: DeliNode): string =
  result = if node.sons.len < 1:
    "{" & ($node).replace(" ","|") & "}"
  else:
    ($node.kind)[2..^1]

proc recordLabel(node: DeliNode): string =
  result = "{" & basicLabel(node) & "|{" & node.sons.map(
    proc(x:DeliNode):string =
      basicLabel(x)
  ).join("|") & "}}"

proc buildGraph(graph: var Graph[Arrow], node: DeliNode) =
  let node_id = nodeId(node)
  var label = basicLabel(node)

  case node.kind
  of dkComparison,
     dkCode,
     dkConditional:
    label = recordLabel(node)
  else:
    if ($node.kind)[^4..^1] == "Stmt":
      label = recordLabel(node)
    elif ($node.kind)[^4..^1] == "Loop":
      label = recordLabel(node)

  graph.addNode(node_id, ("label", label))
  if node.sons.len < 1:
    return

  var sub: Graph[Arrow]
  if node.sons.len > 1:
    sub = newGraph(graph)
    sub.graphAttr["rank"] = "same"
    sub.name = "order_" & $node_id

  var prevson: DeliNode = nil
  for son in node.sons:
    let son_id = nodeId(son)
    graph.addEdge( node_id -> son_id )
    graph.buildGraph(son)

    if prevson != nil:
      sub.addEdge( nodeId(prevson) -> son_id )
    prevson = son

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

proc write_chunked(data: var string, cmd: var Table[string, string]): string =
  result = ""
  #var data = encode(image)
  var remain = data.len()
  while remain > 0:
    remain = min( 4096, data.len() )
    let chunk = data[0..remain-1]
    data = data[remain..^1]
    let m = if remain < 4096: "0"
    else: "1"
    cmd["m"] = m
    result = result & serialize_gr_command(chunk, cmd)
    #stdout.flushFile()
    cmd.clear()
    if remain < 4096: break


proc kittyGraphics(input: var string): string =
  var params = {"a": "T", "f": "100"}.toTable
  return write_chunked(input, params)

proc graphviz(input: string): string =
  let cmd = "dot " & dotargs.join(" ") & " | base64 | tr -d '\n'"  # & " | kitty " & icatargs.join(" ")
  return execCmdEx(cmd, input = input).output.strip()

proc renderGraph(graph: Graph[Arrow]): string =
  var png = graphviz(graph.exportDot())
  return kittyGraphics(png)

proc renderGraph*(node: DeliNode): string =
  var graph = newGraph[Arrow]()
  graph.buildGraph(node)
  #return graph.exportDot()
  return "\n" & graph.renderGraph()

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

  echo graph.renderGraph()
  #echo graph.exportDot()


  #let cmd = "dot " & dotargs.join(" ") & " | base64 | tr -d '\n'"  # & " | kitty " & icatargs.join(" ")
  ##echo cmd
  #var b64png = execCmdEx(cmd, input = graph.exportDot()).output.strip()
  ##stdout.write( png )
  #var params = {"a": "T", "f": "100"}.toTable
  #echo write_chunked(b64png, params)
  ##discard execCmdEx("kitty " & icatargs.join(" "), input=png)
  ##echo ""

