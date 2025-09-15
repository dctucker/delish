
import times
import strutils
import deliparser
import deliargs
import deliast
import deliengine
import delinteract
import deliscript

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = 1000 * (epochTime() - t0)
    if debug > 0:
      echo "CPU Time [", benchmarkName, "] ", elapsed.formatFloat(ffDecimal, 2), "ms"

when isMainModule:
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

  let script = loadScript(filename)
  let parser = Parser(script: script, debug: debug)
  var parsed: DeliNode
  benchmark "parsing":
    parsed = parser.parse()

  if parser.parsed_len != script.source.len():
    stderr.write("\n*** ERROR: Stopped parsing at pos ", parser.parsed_len, "/", script.source.len(), "\n")
    let num = script.line_number(parser.parsed_len)
    let errline = script.getLine(num)
    stderr.write("Syntax error in ", filename, ":", num, " near \"", errline, "\"\n\n")
    quit 1

  var engine: Engine
  var nteract: Nteract
  benchmark "executing":
    #benchmark "engine setup":
    engine = newEngine(parsed, debug)
    nteract = newNteract(engine)

    for line in engine.tick():
      if debug > 0:
        echo engine.lineInfo()
      if interactive:
        nteract.line = line.abs
        nteract.filename = engine.sourceFile()
        if line > 0:
          discard nteract.getUserInput()

  quit engine.retval().intVal

