# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import os
import times
import deliparser
import deliengine
import delinteract

#when isMainModule:
#  import delinpeg

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = epochTime() - t0
    echo "CPU Time [", benchmarkName, "] ", elapsed, "s"


when isMainModule:
#  import pegs
#  import std/marshal
#  import std/streams
#  let serial = newFileStream("./src/deligrammar.json", fmRead).readAll()
#  let grammar_unmarshal = to[Peg](serial)
#  #echo grammar_unmarshal.repr
#
#when false:
  let interactive = false
  let debug = true
  let breakpoints = @[53]

  if paramCount() < 1:
    echo "usage: delish script.deli"
    quit 2

  let filename = paramStr(1)
  let source = readFile(filename)
  let parser = Parser(source: source, debug: debug)
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
  var nteract = newNteract(engine)
  nteract.filename = filename

  proc mainloop() =
    for line in engine.tick():
      echo engine.lineInfo(line)
      if interactive:
        nteract.line = line.abs
        discard nteract.getUserInput()

  if interactive:
    mainloop()
  else:
    benchmark "executing":
      mainloop()


