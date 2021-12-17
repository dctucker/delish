import std/tables
import strutils
import stacks
import deligrammar

### AST representation
grammarToEnum(@["None","Ran","Lazy","S","W","U"])
grammarToCEnum(@["None","Ran","Lazy","S","W","_"])

proc something*(kind: cint, str: cstring, len: cint): cint {.exportc.} =
  result = kind
  let k = DeliKind(kind)
  echo $k, " ", str

proc deli_event(auxil: pointer, event: cint, rule: cint, level: cint, pos: csize_t, buffer: cstring, length: csize_t) {.exportc.} =
  let k = DeliKind(rule.int)
  case k
  of dkS, dkW, dkU, dkBlank, dkVLine, dkComment:
    return
  else:
    discard
  var e = ""
  var capture = ""
  case event
    of 0:
      e = "> "
    of 1:
      e = "\27[1m< "
      capture = newString(length)
      if length > 0:
        for i in 0 .. length - 1:
          capture[i] = buffer[i].char
    of 2:
      e = "< "
    else:
      e = "  "
  echo indent(e, level * 2), $k, " ", capture.split("\n")[0], "\27[0m"

{.compile: "packcc.c" .}
proc packcc_main*(input: cstring, len: cint): cint {.importc.}

proc matched(str: cstring) {.cdecl.} =
  #setupForeignThreadGc()
  echo str



type
  DeliNode* = ref object
    case kind*: DeliKind
    of dkNone:         none:        bool
    of dkIdentifier:   id*:         string
    of dkPath,
       dkStrBlock,
       dkStrLiteral,
       dkString:       strVal*:     string
    of dkStream,
       dkInteger:      intVal*:     int
    of dkBoolean:      boolVal*:    bool
    of dkVariable:     varName*:    string
    of dkInvocation:   cmd*:        string
    of dkObject:       table*:      Table[string, DeliNode]
    of dkArgShort,
       dkArgLong,
       dkArg:          argName*:    string
    of dkArgStmt:      short_name*, long_name*, default_value*: DeliNode
    of dkIncludeStmt:  includeVal*: DeliNode
    of dkFunctionStmt: funcName*:   DeliNode
    else:
      discard
    sons*: seq[DeliNode]
    line*: int

proc isNone*(node: DeliNode):bool =
  if node.kind == dkNone:
    return true
  return false

proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)

proc `$`*(node: DeliNode): string
proc toString*(node: DeliNode):string =
  if node.kind == dkExpr:
    result = ""
    for s in node.sons:
      result &= s.toString()
      result &= " "
    return result
  return case node.kind
  of dkIdentifier: node.id
  of dkPath,
     dkStrLiteral,
     dkStrBlock,
     dkString:     node.strVal
  of dkStream,
     dkInteger:    $(node.intVal)
  of dkBoolean:    $(node.boolVal)
  of dkVariable:   $(node.varName)
  of dkArgDefault: $(node.sons[0])
  of dkInvocation: node.cmd
  of dkArg:
    node.sons[0].toString()
  of dkArgShort, dkArgLong:
    $(node.argName)
  of dkObject:     $(node.table)
  else: ""

proc `$`*(node: DeliNode): string =
  let value = node.toString()
  if value == "":
    return ($(node.kind)).substr(2)
  else:
    return ($(node.kind)).substr(2) & " " & value

import strutils
proc todo*(msg: varargs[string, `$`]) =
  stderr.write("\27[0;33mTODO: ", msg.join(""), "\27[0m\n")

