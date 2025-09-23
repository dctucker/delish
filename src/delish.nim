
import std/times
import std/strutils
import ./deliparser
import ./deliargs
import ./deliast
import ./deliengine
import ./delinteract
import ./deliscript
import ./delilog

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = 1000 * (epochTime() - t0)
    if debug > 0:
      echo "\27[36mCPU Time [", benchmarkName, "] ", elapsed.formatFloat(ffDecimal, 2), "ms\27[0m"

proc exception_handler*(e: ref Exception, debug: int) =
  errlog.write("\27[31m")
  if debug > 0:
    errlog.write(e.getStackTrace())
  errlog.write(e.msg)
  errlog.write("\n")
  errlog.write("\27[0m")

proc delish_main*(cmdline: seq[string] = @[]): int =
  var interactive = false
  var command_mode = false
  var parse_only = false
  var slowmo = false
  var debug = 0
  var breakpoints = @[54]
  var mainarg = ""
  var scriptname: string
  var script: DeliScript

  initUserArguments(cmdline)

  while user_args.len() > 0:
    let arg = shift()
    #echo arg
    if arg.isFlag():
      if arg.short_name == "p":
        parse_only = true
      if arg.short_name == "s":
        slowmo = true
      if arg.short_name == "i":
        interactive = true
      if arg.short_name == "d":
        debug += 1
      if arg.short_name == "c":
        command_mode = true
    else:
      if not arg.isNone():
        mainarg = arg.value.toString()
        break

  if mainarg == "":
    errlog.write("usage: delish script.deli\n")
    return 2

  if command_mode:
    scriptname = "-c"
    script = makeScript(scriptname, mainarg & "\n")
  else:
    scriptname = mainarg
    script = loadScript(scriptname)

  let parser = Parser(script: script, debug: debug, slowmo: slowmo)
  var parsed: DeliNode
  benchmark "parsing":
    parsed = parser.parse()

  if parser.parsed_len != script.source.len():
    #errlog.write("\n*** ERROR: Stopped parsing at pos ", parser.parsed_len, "/", script.source.len(), "\n")
    let row = script.line_number(parser.parsed_len)
    let col = script.col_number(parser.parsed_len)
    let errline = script.getLine(row)
    errlog.write(scriptname, ":", row, ":", col, ": error")
    for err in parser.errors:
      errlog.write(": ", err.msg)
    errlog.write("\n ", errline, "\n ")
    errlog.write(repeat(" ", col), "^\n")
    return 1

  if parser.errors.len != 0:
    for err in parser.errors:
      let row = script.line_number(err.pos)
      let col = script.col_number(err.pos)
      errlog.write(scriptname, ":", row, ":", col, ": ", err.msg, "\n")
    return 1


  var engine: Engine
  var nteract: Nteract
  benchmark "executing":
    #benchmark "engine setup":
    try:
      engine = newEngine(parsed, debug)
      nteract = newNteract(engine)

      if parse_only:
        engine.printStatements()
        return 0

      for line in engine.tick():
        if debug > 0:
          echo engine.lineInfo()
        if interactive:
          nteract.line = line.abs
          nteract.filename = engine.sourceFile()
          if line > 0:
            discard nteract.getUserInput()
    except SetupError as e:
      exception_handler(e, debug)
      return 2
    except RuntimeError as e:
      exception_handler(e, debug)
      return 1
    except InterruptError as e:
      exception_handler(e, debug)
      return 127

  return engine.retval().intVal

when isMainModule:
  quit delish_main()
