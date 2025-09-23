import std/lists
import std/tables
import std/strutils
#import stacks
import ./deligrammar
import ./deliscript
import ./delilog

### AST representation
grammarToEnum( @["None","Inner","Ran","Jump","Lazy","A","C","S","W","U"])
grammarToCEnum(@["None","Inner","Ran","Jump","Lazy","A","C","S","W","_"])
grammarSubKinds("Statement")
grammarSubKinds("Type")
grammarSubKinds("CompExpr")
grammarSubKinds("Comparator")
grammarSubKinds("RedirOp")
grammarKindStrings("Type")
grammarSubKindStrings("Comparator")

const deliTypes* = {
  dkInteger,
  dkArg,
  dkArray,
  dkBoolean,
  dkIdentifier,
  dkPath,
  dkObject,
  dkRegex,
  dkStream,
  dkString,
  dkVariable,
}

type
  DeliNode* = ref DeliNodeObj
  DeliList* = SinglyLinkedList[DeliNode]
  DeliListNode* = SinglyLinkedNode[DeliNode]
  DeliTable* = Table[string, DeliNode]

  Decimal* = object
    whole*, fraction*, decimals*: int

  DeliNodeObj* = object
    case kind*: DeliKind
    of dkNone:         none:        bool
    of dkIdentifier:   id*:         string
    of dkPath,
       dkStrBlock,
       dkStrLiteral,
       dkString:       strVal*:     string
    of dkRegex:        pattern*:    string
    of dkStream,
       dkInteger:      intVal*:     int
    of dkDecimal:      decVal*:     Decimal
    of dkBoolean:      boolVal*:    bool
    of dkVariable:     varName*:    string
    of dkInvocation:   cmd*:        string
    of dkObject,
       dkRan:          table*:      DeliTable
    of dkArgShort,
       dkArgLong,
       dkArg:          argName*:    string
    of dkArgStmt:      short_name*, long_name*, default_value*: DeliNode
    of dkFunctionCall: funcName*:   DeliNode
    of dkJump,
       dkWhileLoop,
       dkDoLoop,
       dkConditional,
       dkForLoop:      list_node*:  DeliListNode
    else:
      discard
    sons*: seq[DeliNode]
    line*: int
    script*:     DeliScript

proc isNone*(node: DeliNode):bool =
  if node.kind == dkNone:
    return true
  return false

proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)


proc DK*(kind: DeliKind, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    sons.add(node)
  return DeliNode(kind: kind, sons: sons)

proc DKExpr*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExpr )
  for node in nodes:
    result.sons.add(node)

proc DKExprList*(nodes: varargs[DeliNode]): DeliNode =
  result = DK( dkExprList )
  for node in nodes:
    result.sons.add(node)


proc DKArg*(argName: string): DeliNode =
  if argName.len == 0:
    raise newException(ValueError, "empty argument name")
  if argName.len == 1:
    return DeliNode(kind: dkArgShort, argName: argName)
  return DeliNode(kind: dkArgLong, argName: argName)

proc DKId*(id: string): DeliNode =
  return DeliNode(kind: dkIdentifier, id: id)

proc DKVar*(varName: string): DeliNode =
  return DeliNode(kind: dkVariable, varName: varName)

proc DKVarStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkVariableStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKLocalStmt*(v: string, op: DeliKind, val: DeliNode): DeliNode =
  return DK( dkLocalStmt, DKVar(v), DK( op ), DKExpr(val) )

proc DKInt*(intVal: int): DeliNode =
  return DeliNode(kind: dkInteger, intVal: intVal)

proc DKDecimal*(whole, fraction: int, decimals: int): DeliNode =
  return DeliNode(kind: dkDecimal, decVal: Decimal(whole: whole, fraction: fraction, decimals: decimals))

proc DKBool*(boolVal: bool): DeliNode =
  return DeliNode(kind: dkBoolean, boolVal: boolVal)

proc deliTrue* (): DeliNode = DKBool(true)
proc deliFalse*(): DeliNode = DKBool(false)

proc DKLazy*(node: DeliNode): DeliNode =
  return DeliNode(kind: dkLazy, sons: @[node])

proc DKNotNone*(node: DeliNode): DeliNode =
  return DeliNode(kind: dkBoolExpr, sons: @[
    node, DeliNode(kind: dkCompNe), deliNone()
  ])

proc DKStr*(strVal: string): DeliNode =
  return DeliNode(kind: dkString, strVal: strVal)

proc DKStream*(intVal: int): DeliNode =
  return DeliNode(kind: dkStream, intVal: intVal)

proc DKRan*(): DeliNode =
  return DeliNode(kind: dkRan, table: {
    "id": DeliNode(kind: dkNone),
    "in":  DeliNode(kind: dkNone),
    "out": DeliNode(kind: dkNone),
    "err": DeliNode(kind: dkNone),
    "exit": DeliNode(kind: dkNone),
  }.toTable)

proc DKPath*(strVal: string): DeliNode =
  return DeliNode(kind: dkPath, strVal: strVal)

proc DKStmt*(kind: DeliKind, args: varargs[DeliNode]): DeliNode =
  return DK( dkStatement, DK( kind, args ) )

proc DKInner*(line: int, nodes: varargs[DeliNode]): DeliNode =
  var sons: seq[DeliNode] = @[]
  for node in nodes:
    node.line = line
    sons.add(node)
  return DeliNode(kind: dkInner, sons: sons, line: line)

let DKTrue*  = DeliNode(kind: dkBoolean, boolVal: true)
let DKFalse* = DeliNode(kind: dkBoolean, boolVal: false)

proc DeliObject*(table: openArray[tuple[key: string, val: DeliNode]]): DeliNode =
  return DeliNode(kind: dkObject, table: table.toTable)

proc `$`*(node: DeliNode): string
proc toString*(node: DeliNode):string

proc argFormat(node: DeliNode): string =
  var current_kind = dkNone
  result = ""
  for son in node.sons:
    case son.kind
    of dkArgLong:
      if current_kind != son.kind:
        result &= " "
      result &= "--" & son.argName
    of dkArgShort:
      if current_kind != son.kind:
        result &= "-"
      result &= son.argName
    of dkArg:
      let a = son.sons[0]
      case a.kind
      of dkArgLong:
        if current_kind != a.kind and result.len > 0:
          result &= " "
        result &= "--" & a.argName
      of dkArgShort:
        if current_kind != a.kind:
          result &= "-"
        result &= a.argName
      else:
        result &= $a
      current_kind = a.kind
      continue
    of dkString:
      result &= son.strVal
    of dkExpr:
      result &= " " & son.sons[0].toString
    else:
      result &= $son
    current_kind = son.kind

proc objFormat(node: DeliNode): string =
  result = "["
  for key,value in node.table:
    result &= key & ": " & value.toString() & "; "
  result &= "]"

proc `$`*(decimal: Decimal): string =
  return $(decimal.whole) & '.' & align($(decimal.fraction), decimal.decimals, '0')

proc toString*(node: DeliNode): string =
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
  of dkDecimal:    $(node.decVal)
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
    argFormat(node)
  of dkArgShort:
    "-" & node.argName
  of dkArgLong:
    "--" & node.argName
  of dkArgExpr:
    argFormat(node)
  of dkObject, dkRan:
    objFormat(node)
  of dkJump:
    if node.list_node != nil:
      $node.list_node.value.line
    else:
      "Jump"
  else: ""

proc name*(kind: DeliKind): string =
  return ($kind).substr(2)

proc `$`*(node: DeliNode): string =
  let value = node.toString()
  if value == "":
    return node.kind.name
  else:
    return node.kind.name & ":" & value

proc todo*(msg: varargs[string, `$`]) =
  errlog.write("\27[0;33mTODO: ", msg.join(""), "\27[0m\n")

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
  of dkCloseStmt:
    return "close $" & node.sons[0].varName
  of dkLocalStmt:
    result = "local $" & node.sons[0].varName
    if node.sons.len > 1:
      result &= " = " & node.sons[1].toString()
  of dkPush: return "push"
  of dkPop:  return "pop"
  of dkJump:
    let line = if node.list_node == nil:
      "end"
    else:
      $(node.list_node.value.line)
    return "jump :" & line
  of dkInner:
    result = "{ "
    for son in node.sons:
      result &= son.getOneliner()
      result &= " ; "
    result = result[0..^4] & " }"
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

proc printObject(node: DeliNode): string =
  for k,v in node.table.pairs():
    result &= k & ": " & $v
    result &= "; "

proc printValue*(v: DeliNode): string =
  result = "\27[30;1m"
  if( v.sons.len() > 0 ):
    result &= "("
    result &= printSons(v)
    result &= ")"
  if v.kind == dkObject:
    result &= "["
    result &= printObject(v)
    result &= "]"
  result &= "\27[0m"


proc setLine*(node: var DeliNode, line: int): DeliNode =
  result = node
  result.line = line

