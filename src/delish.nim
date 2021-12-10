# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deliparser
import deliengine
import os
import times

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = epochTime() - t0
    echo "CPU Time [", benchmarkName, "] ", elapsed, "s"

when isMainModule:
  if paramCount() < 1:
    echo "usage: delish script.deli"
    quit 2

  let source = readFile(paramStr(1))
  let parser = Parser(source: source)
  var parsed_len = 0
  benchmark "parsing":
    parsed_len = parser.parse()
  #parser.printStackTable()
  parser.printEntryPoint()

  if parsed_len != source.len():
    stderr.write("\n*** ERROR: Stopped parsing at pos ", parsed_len, "/", source.len(), "\n")
    quit 1

  let script = parser.getScript()
  var engine: Engine = newEngine()

  benchmark "executing":
    for line in engine.tick(script):
      let sline = parser.getLine(line)
      stdout.write( "\27[1;30m:", line, " \27[0;34;4m", sline, "\27[1;24m" )

