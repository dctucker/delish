import osproc
import streams
#import std/strutils
import nimgraphviz

import deliast

proc icat(input: Stream): Process =
  let icat = try:
    startProcess("kitty", args=["+kitten", "icat", "--align","left"], options={poUsePath})
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

proc dot(input: Stream, format: string = "png"): Process =
  let dot =
    try:
      startProcess("dot", args=[
        "-Kdot",
        "-T" & format,
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
      ], options={poUsePath})
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

  discard graph.renderGraph()

