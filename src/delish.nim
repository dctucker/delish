
import times
import deliparser
import deliargs
import deliast
import deliengine
import delinteract

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
  var interactive = false
  var debug = 0
  var breakpoints = @[54]
  var filename = ""

  initUserArguments()

  while user_args.len() > 0:
    let arg = shift()
    #echo arg
    if arg.isFlag():
      if arg.short_name == "i":
        interactive = true
      if arg.short_name == "d":
        debug += 1
    else:
      if not arg.isNone():
        filename = arg.value.toString()
        break

  if filename == "":
    stderr.write("usage: delish script.deli\n")
    quit 2

  let source = readFile(filename)
  let parser = Parser(source: source, debug: debug > 0)
  var parsed_len = 0
  if debug > 0:
    benchmark "parsing":
      parsed_len = parser.parse()
  else:
    parsed_len = parser.parse()

  if parsed_len != source.len():
    stderr.write("\n*** ERROR: Stopped parsing at pos ", parsed_len, "/", source.len(), "\n")
    let num = parser.line_number(parsed_len)
    let errline = parser.getLine(num)
    stderr.write("Syntax error in ", filename, ":", num, " near ", errline, "\n\n")
    quit 1

  var engine: Engine = newEngine(parser, debug)
  var nteract = newNteract(engine)
  nteract.filename = filename

  proc mainloop() =
    for line in engine.tick():
      if debug > 0:
        echo engine.lineInfo(line)
      if interactive:
        nteract.line = line.abs
        if line > 0:
          discard nteract.getUserInput()

  if debug > 0:
    benchmark "executing":
      mainloop()
  else:
    mainloop()

