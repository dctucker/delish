const profiler {.booldefine.}: bool = false
when profiler:
  import nimprof

import std/[
  times,
  strutils,
]
import ./language/[
  parser,
  ast,
]
import ./[
  argument,
  deliengine,
  delinteract,
  deliscript,
  delilog,
]

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
  var interactive_only = false
  var command_mode = false
  var parse_only = false
  var slowmo = false
  var debug = 0
  var breakpoints = @[54]
  var mainarg = ""
  var scriptname: string
  var script: DeliScript

  initUserArguments(cmdline)

  # parse all cmdline args
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

  if mainarg == "" and not interactive:
    errlog.write("usage: delish script.deli\n")
    return 2

  # setup the script based on args
  if command_mode:
    scriptname = "-c"
    script = makeScript(scriptname, mainarg & "\n")
  elif interactive and mainarg == "":
    scriptname = "in"
    script = makeScript(scriptname, "\n")
    interactive_only = true
  else:
    scriptname = mainarg
    script = loadScript(scriptname)

  # setup parser
  let parser = Parser(script: script, debug: debug, slowmo: slowmo)
  var parsed: DeliNode

  var engine: Engine
  var nteract: Nteract

  # interactive mode with no script specified
  if interactive_only:
    echo "Interactive mode"
    parsed = parser.parse()
    engine = newEngine(parsed, debug)
    nteract = newNteract(engine)
    nteract.setPrompt(dkPath)

    var line = 0
    while true:
      try:
        nteract.cmdline = ""
        let input = nteract.getUserInput()
        if input == "exit":
          break
        if input.strip.len > 0:
          script = makeScript(scriptname, "\n".repeat(line) & input & "\n")
          parser.script = script
          parsed = parser.parse()

          if parser.errors.len != 0 or parsed.kind != dkScript:
            errlog.write "parser error"
            for err in parser.errors:
              let row = script.line_number(err.pos)
              let col = script.col_number(err.pos)
              errlog.write(scriptname, ":", row, ":", col, ": ", err.msg, "\n")
            continue

          #echo parsed.repr
          for s in parsed.sons:
            engine.insertStmt(s)
            line += 1

        #engine.printStatements(true)
        for line in engine.tick():
          if debug > 0:
            echo engine.lineInfo()

      except InterruptError as e:
        stderr.write "\27[31m", e.msg, "\27[0m\n"
        return 0
      except RuntimeError as e:
        exception_handler(e, 2)
        engine.printStatements(true)
      except SetupError as e:
        exception_handler(e, 2)
        engine.printStatements(true)

  # script mode follows
  benchmark "parsing":
    if debug >= 2:
      stderr.write "\27[?7l"
    parsed = parser.parse()

    if debug >= 2:
      parser.printMetrics

    if debug >= 2:
      stderr.write "\27[?7h"

  # check whether the parser read the entire script
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

  # check whether the parser has errors
  if parser.errors.len != 0:
    for err in parser.errors:
      let row = script.line_number(err.pos)
      let col = script.col_number(err.pos)
      errlog.write(scriptname, ":", row, ":", col, ": ", err.msg, "\n")
    return 1

  # execution loop
  benchmark "executing":
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
            discard nteract.getUserInput(engine.sourceLine())

    except SetupError as e:
      exception_handler(e, debug)
      return 2
    except RuntimeError as e:
      exception_handler(e, debug)
      return 1
    except InterruptError as e:
      exception_handler(e, 0)
      return 127

  return engine.retval().intVal

when isMainModule:
  quit delish_main()
