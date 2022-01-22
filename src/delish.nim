
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
  var parsed_len = 0
  if debug > 0:
    benchmark "parsing":
      parsed_len = parser.parse()
  else:
    parsed_len = parser.parse()

  if parsed_len != script.source.len():
    stderr.write("\n*** ERROR: Stopped parsing at pos ", parsed_len, "/", script.source.len(), "\n")
    let num = parser.script.line_number(parsed_len)
    let errline = parser.script.getLine(num)
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

