import std/tables
import strutils
import stacks
import deligrammar

### AST representation
grammarToEnum(@["None","Ran","Lazy"])
grammarToCEnum(@["None","Ran","Lazy"])

proc something*(kind: cint, str: cstring, len: cint): cint {.exportc.} =
  result = kind
  let k = DeliKind(kind)
  echo $k, " ", str

var level = 0
var kindstack = Stack[DeliKind]()
proc yyenter(kind: cint) {.exportc.} =
  let k = DeliKind(kind)
  #let level = kindstack.len
  level += 1
  echo level, "> ", $k
  #kindstack.push(k)

proc yyleave(kind: cint) {.exportc.} =
  let k = DeliKind(kind)
  #while kindstack.len > 0:
  #  let k2 = kindstack.pop()
  #  #let level = kindstack.len
  #  level -= 1
  #  echo level, "< ", $k2
  #  if k2 == k:
  #    break
  #let level = kindstack.len
  level -= 1
  echo level, "< ", $k

{.compile: "delish.yy.c" .}
proc yyparse*(): cint {.importc.}
proc yySetScript*(str: cstring) {.importc.}
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

