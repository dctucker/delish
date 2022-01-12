import std/tables
import std/lists
import std/tables
import strutils
#import stacks
import deligrammar

### AST representation
grammarToEnum( @["None","Inner","Ran","Jump","Lazy","S","W","U"])
grammarToCEnum(@["None","Inner","Ran","Jump","Lazy","S","W","_"])

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
  of dkArgShort:
    "-" & node.argName
  of dkArgLong:
    "--" & node.argName
  of dkArgExpr:
    node.sons[0].toString & " " & node.sons[1].toString
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


proc `+`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: a.intVal + b.intval)
    of dkString:
      return DeliNode(kind: dkString, strVal: a.strVal & b.strVal)
    of dkArray:
      result = DeliNode(kind: dkArray)
      for n in a.sons:
        result.sons.add(n)
      for n in b.sons:
        result.sons.add(n)
        return result
    else:
      return deliNone()

  case a.kind
  of dkArray:
    a.sons.add(b)
    return a
  else:
    todo "add ", a.kind, " + ", b.kind
    return a

  return deliNone()

proc repr*(node: DeliNode): string =
  result = ""
  result &= $node
  if node.sons.len() > 0:
    result &= "( "
    for n in node.sons:
      result &= repr(n)
    result &= ")"
  result &= " "

proc getOneliner*(node: DeliNode): string =
  case node.kind
  of dkNone:
    return "nop"
  of dkVariableStmt:
    return "$" & node.sons[0].varName & " " & node.sons[1].toString() & " " & node.sons[2].toString()
  of dkLocalStmt:
    result = "local $" & node.sons[0].varName
    if node.sons.len > 1:
      result &= " = " & node.sons[1].toString()
  of dkPush: return "push"
  of dkPop:  return "pop"
  of dkJump:
    let line = if node.node == nil:
      "end"
    else:
      $(node.node.value.line)
    return "jump :" & line
  of dkInner:
    result = ""
    for son in node.sons:
      result &= son.getOneliner()
      result &= " ; "
    result = result[0..^4]
  of dkConditional:
    return "if " & $(node.sons[0].repr) & $(node.sons[1].repr)
  of dkReturnStmt, dkBreakStmt, dkContinueStmt:
    let k = $(node.kind)
    return k.substr(2, k.len - 5).toLowerAscii
  else:
    return $(node.kind) & "?"

proc printSons*(node: DeliNode): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= " " & $son
      if son.sons.len() > 0:
        result &= "("
        result &= printSons(son)
        result &= ") "

proc printSons*(node: DeliNode, level: int): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= indent($son, 4*level)
      result &= printSons(son, level+1)

proc printValue*(v: DeliNode): string =
  result = "\27[30;1m"
  if( v.sons.len() > 0 ):
    result &= "("
    result &= printSons(v)
    result &= ")"
  result &= "\27[0m"


proc DK*(kind: DeliKind, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    sons.add(node)
  return DeliNode(kind: kind, sons: sons)

proc DKVar*(varName: string): DeliNode =
  return DeliNode(kind: dkVariable, varName: varName)

proc DKInt*(intVal: int): DeliNode =
  return DeliNode(kind: dkInteger, intVal: intVal)

proc DKInner*(line: int, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    sons.add(node)
  return DeliNode(kind: dkInner, sons: sons, line: line)

proc setLine*(node: var DeliNode, line: int): DeliNode =
  result = node
  result.line = line

proc DeliObject*(table: openArray[tuple[key: string, val: DeliNode]]): DeliNode =
  return DeliNode(kind: dkObject, table: table.toTable)

