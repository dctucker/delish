import deliengine
import std/terminal

type Nteract* = ref object
  engine: Engine
  filename: string
  line: int
  cmdline: string
  pos: int

proc newNteract*(engine: Engine): Nteract =
  return NTeract(engine: engine)

proc prompt*(nt: Nteract): string =
  return nt.filename & ":" & $(nt.line.abs)

proc `filename=`*(nt: Nteract, fn: string) =
  nt.filename = fn

proc `line=`*(nt: Nteract, line: int) =
  nt.line = line

proc left(nt: Nteract) =
  if nt.pos > 0:
    nt.pos -= 1
    cursorBackward()

proc right(nt: Nteract) =
  if nt.pos < nt.cmdline.len:
    nt.pos += 1
    cursorForward()

proc up(nt: Nteract) =
  cursorUp()

proc down(nt: Nteract) =
  cursorDown()

proc clear(nt: Nteract) =
  nt.pos = 0
  nt.cmdline = ""
  stdout.write("\r\27[2K")
  stdout.write("\27[30;1m")
  stdout.write(nt.prompt)
  stdout.write("\27[0m> ")
  stdout.flushFile()

proc drawRemaining(nt: Nteract) =
  stdout.write "\27[?25l\27[0K"
  let remlen = nt.cmdline.len - nt.pos
  for c in [nt.pos .. nt.cmdline.len - 1]:
    stdout.write(nt.cmdline[c])
  if remlen > 0:
    stdout.write("\27[" & $remlen & "D")
  stdout.write "\27[?25h"

proc insert(nt: Nteract, k: string) =
  nt.cmdline.insert($k, nt.pos)
  nt.pos += 1
  stdout.write(k)
  if nt.pos < nt.cmdline.len:
    nt.drawRemaining()

proc bs(nt: Nteract) =
  if nt.pos == 0 or nt.cmdline.len == 0:
    return
  cursorBackward()
  stdout.write(" ")
  cursorBackward()
  if nt.pos == nt.cmdline.len:
    nt.cmdline = nt.cmdline[0 .. nt.pos - 2]
    nt.pos -= 1
  else:
    nt.cmdline = nt.cmdline[0 .. nt.pos - 2] & nt.cmdline[ nt.pos .. ^1 ]
    nt.pos -= 1
    nt.drawRemaining()

proc fwdel(nt: Nteract) =
  if nt.pos < nt.cmdline.len:
    if nt.pos == 0:
      if nt.cmdline.len <= 1:
        nt.cmdline = ""
        stdout.write(" ")
        stdout.write("\27[D")
        return
      else:
        nt.cmdline = nt.cmdline[1 .. ^1]
    else:
      nt.cmdline = nt.cmdline[0 .. nt.pos - 1] & nt.cmdline[ nt.pos+1 .. ^1 ]
    nt.drawRemaining()

proc getUserInput*(nt: Nteract): string =
  nt.clear()
  nt.cmdline = nt.engine.sourceLine()
  nt.pos = nt.cmdline.len
  stdout.write(nt.cmdline)
  stdout.flushFile()

  var first = true
  while true:
    let k = getch()
    case k
    of '\3':
      raise InterruptError(msg: "^C")
    of '\7', '\127':
      if first:
        nt.clear()
      else:
        nt.bs()
    of '\10', '\13':
      echo ""
      return nt.cmdline
    of '\27':
      case getch()
      of '[':
        case getch()
        of 'A': nt.up()
        of 'B': nt.down()
        of 'C': nt.right()
        of 'D': nt.left()
        of '3':
          case getch()
          of '~': nt.fwdel()
          else: discard
        else: discard
      else: discard
    else:
      nt.insert($k)
    first = false
