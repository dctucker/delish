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

  let filename = paramStr(1)
  let source = readFile(filename)
  let parser = Parser(source: source, debug: false)
  var parsed_len = 0
  benchmark "parsing":
    parsed_len = parser.parse()
  #parser.printStackTable()
  #parser.printEntryPoint()

  if parsed_len != source.len():
    stderr.write("\n*** ERROR: Stopped parsing at pos ", parsed_len, "/", source.len(), "\n")
    let num = parser.line_number(parsed_len)
    let errline = parser.getLine(num)
    stderr.write("Syntax error in ", filename, ":", num, " near ", errline, "\n\n")
    quit 1

  var engine: Engine = newEngine(parser)
  benchmark "executing":
    for line in engine.tick():
      echo "\27[0m"

