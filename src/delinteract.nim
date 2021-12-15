import deliengine
import std/terminal

type Nteract = ref object
  engine: Engine
  filename: string
  line: int

proc newNteract*(engine: Engine): Nteract =
  return NTeract(engine: engine)

proc prompt*(nt: Nteract): string =
  return nt.filename & ":" & $(nt.line.abs)

proc `filename=`*(nt: Nteract, fn: string) =
  nt.filename = fn

proc `line=`*(nt: Nteract, line: int) =
  nt.line = line

proc up(nt: Nteract) =
  cursorUp()
proc left(nt: Nteract) =
  cursorBackward()
proc right(nt: Nteract) =
  cursorForward()
proc down(nt: Nteract) =
  cursorDown()
proc bs(nt: Nteract) =
  cursorBackward()
  stdout.write(" ")
  cursorBackward()

proc getUserInput*(nt: Nteract): string =
  stdout.write("\27[30;1m")
  stdout.write(nt.prompt())
  stdout.write("\27[0m> ")
  stdout.write(nt.engine.sourceLine(nt.line))
  stdout.flushFile()

  var cmdline = ""
  while true:
    let k = getch()
    case k
    of '\3':
      echo "^C"
      quit 127
    of '\7', '\127':
      nt.bs()
    of '\10', '\13':
      echo ""
      return cmdline
    of '\27':
      case getch()
      of '[':
        case getch()
        of 'A': nt.up()
        of 'B': nt.down()
        of 'C': nt.right()
        of 'D': nt.left()
        else:
          discard
      else:
        discard
    else:
      stdout.write(k)
      continue
