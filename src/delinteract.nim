import std/terminal
import std/paths

import ./language/ast
import ./deliengine

type
  Nteract* = ref object
    engine: Engine
    filename: string
    line: int
    cmdline: string
    ps1: string
    promptKind: DeliKind
    pos: int

proc newNteract*(engine: Engine): Nteract =
  result = Nteract(engine: engine)
  result.promptKind = dkScript

proc setPrompt*(nt: Nteract, kind: DeliKind) =
  case kind
  of dkPath:
    nt.ps1 = "Path.pwd, \" . \""
  of dkScript:
    nt.ps1 = "Script.name, \":\", Script.line, \"> \""
  else:
    nt.ps1 = "> "
    return

  nt.promptKind = kind

proc prompt*(nt: Nteract): string =
  case nt.promptKind
  of dkPath:
    return $getCurrentDir()
  of dkScript:
    return nt.filename & ":" & $(nt.line.abs)
  else:
    return nt.ps1

proc clear(nt: Nteract) =
  nt.pos = 0
  nt.cmdline = ""
  stdout.write("\r\27[2K")
  stdout.write("\27[36;4m")
  stdout.write(nt.prompt)
  stdout.write("\27[24;1m> \27[0m")
  stdout.flushFile()

proc `filename=`*(nt: Nteract, fn: string) =
  nt.filename = fn

proc `line=`*(nt: Nteract, line: int) =
  nt.line = line

proc `cmdline=`*(nt: Nteract, cmdline: string) =
  nt.cmdline = cmdline
  nt.pos = nt.cmdline.len

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

proc getUserInput*(nt: Nteract, cmdline: string = ""): string =
  nt.clear()
  nt.cmdline = cmdline
  stdout.write(nt.cmdline)
  stdout.flushFile()

  var first = true
  while true:
    let k = getch()
    case k
    of '\3':
      raise InterruptError(msg: "^C")
    of '\4':
      raise InterruptError(msg: "^D")
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
