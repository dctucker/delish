import osproc
import streams
import std/strutils
import nimgraphviz

proc pipe(i,o: Stream) =
  while not i.atEnd():
    let x = i.readChar()
    o.write(x)
  o.flush()


proc icat(input: Stream, output: Stream = newFileStream(stdout)): Process =
  let icat = try:
    startProcess("kitty", args=["+kitten", "icat", "--align","left"], options={poUsePath})
  except OSError:
    raise
  icat.inputStream.write(input.readAll())
  #icat.inputStream.pipe(input)
  icat.inputStream.close()
  #discard icat.waitForExit()
  #output.write(icat.outputStream.readAll())
  result = icat

proc rsvg(input: Stream, output: Stream = newFileStream(stdout)): Process =
  let rsvg = try:
    startProcess("rsvg-convert", args=["-d144", "-p144"], options={poUsePath})
  except OSError:
    raise
  rsvg.inputStream.write(input.readAll())
  #rsvg.inputStream.pipe(input)
  rsvg.inputStream.close()
  #discard rsvg.waitForExit()
  #output.write(rsvg.outputStream.readAll())
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

#graph.exportImage("test_graph.png")

var procs: seq[Process] = @[]

procs.add( graph.dot() )
#procs.add( rsvg( procs[^1].outputStream ) )
procs.add( icat( procs[^1].outputStream ) )

for p in procs:
  stderr.write(p.errorStream.readAll())
  discard p.waitForExit()
  p.close()

