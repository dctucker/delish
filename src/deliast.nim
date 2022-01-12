import std/tables
import std/lists
import std/tables
import strutils
#import stacks
import deligrammar

### AST representation
grammarToEnum(@["None","Ran","Jump","Lazy","S","W","U"])
grammarToCEnum(@["None","Ran","Jump","Lazy","S","W","_"])

type
  DeliNode* = ref DeliNodeObj
  DeliList* = SinglyLinkedList[DeliNode]
  DeliListNode* = SinglyLinkedNode[DeliNode]
  DeliTable* = Table[string, DeliNode]

  DeliNodeObj* = object
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
    of dkJump:         node*:       DeliListNode
    of dkObject,
       dkRan:          table*:      DeliTable
    of dkArgShort,
       dkArgLong,
       dkArg:          argName*:    string
    of dkArgStmt:      short_name*, long_name*, default_value*: DeliNode
    of dkIncludeStmt:  includeVal*: DeliNode
    of dkFunctionStmt: funcName*:   DeliNode
    of dkForLoop:      counter*:    string
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
  of dkAssignOp: "="
  of dkAppendOp: "+="
  of dkRemoveOp: "-="
  of dkIdentifier: node.id
  of dkPath,
     dkStrLiteral,
     dkStrBlock,
     dkString:     node.strVal
  of dkStream,
     dkInteger:    $(node.intVal)
  of dkBoolean:    $(node.boolVal)
  of dkVariable:   $(node.varName)
  of dkVarDeref:   "VarDeref"
  of dkArgDefault:
    if node.sons.len > 0:
      $(node.sons[0])
    else:
      ""
  of dkInvocation: node.cmd
  of dkArg:
    if node.sons.len > 0:
      node.sons[0].toString()
    else:
      ""
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

