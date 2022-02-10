import osproc
import streams
import std/strutils
import nimgraphviz

proc exportSvg(graph: Graph): string =
  let output = graph.exportDot().split("\n")
  let style = """
    rankdir=LR
    bgcolor=transparent
    color=lightgrey
    node [
      color=gray40
      fontcolor="#dddddd"
      fillcolor="#110844"
      style=filled
      shape=Mrecord
      fontname="Menlo"
      fontsize=10
    ]
    edge [
      color="#99aaff"
      splines=true
    ]
  """
  #echo output[0]
  #echo style
  #for line in output[1 .. ^1]:
  #  echo line

  let process = try:
    startProcess("dot", args=[
      "-Kdot",
      "-Tsvg",
    ], options={poUsePath})
  except OSError:
    raise
  let pin = process.inputStream
  let err = process.errorStream
  pin.write(output[0])
  pin.write(style)
  for line in output[1 .. ^1]:
    pin.write(line)
    pin.write("\n")
  pin.close()
  let code = process.waitForExit()
  let svg = process.outputStream.readAll()
  let errout = err.readAll()
  process.close()

  stderr.write(errout)
  result = svg

proc icat(image: string) =
  let process = try:
    startProcess("kitty", args=[
      "+kitten",
      "icat",
    ], options={poUsePath})
  except OSError:
    raise
  let pin = process.inputStream
  let err = process.errorStream
  pin.write(image)
  pin.close()
  let code = process.waitForExit()
  stdout.write(process.outputStream.readAll())
  let errout = err.readAll()
  stderr.write(errout)


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
icat graph.exportSvg()
