import std/[
  lists,
  tables,
  strutils,
  sequtils,
  times,
]
import ../[
  deliscript,
  delilog,
  errnos,
  signals,
]
import ./[
  grammar
]

### AST representation
grammarToEnum( @["None","Inner","Ran","Jump","Lazy","A","C","S","W","U"])
grammarToCEnum(@["None","Inner","Ran","Jump","Lazy","A","C","S","W","_"])
grammarSubKinds("Statement")
grammarSubKinds("Type")
grammarSubKinds("Stream")
grammarSubKinds("CompExpr")
grammarSubKinds("CompOper")
grammarKindStrings("Type")
grammarSubKindStrings("Stream")
grammarSubKindStrings("CompOper")
grammarOpKinds()
grammarOpKindStrings()

const dkIntegerKinds* = { dkInt10, dkInt8, dkInt16, dkInteger, dkYear, dkMonth, dkDay, dkHour, dkMinute, dkSecond }

type
  DeliNode* = ref DeliNodeObj
  DeliList* = SinglyLinkedList[DeliNode]
  DeliListNode* = SinglyLinkedNode[DeliNode]
  DeliTable* = OrderedTable[string, DeliNode]
  DeliFastTable* = Table[string, DeliNode]

  Decimal* = object
    whole*, fraction*, decimals*: int

  DeliGenerator* = iterator(): DeliNode
  DeliFunction* = proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.}

  DeliValue* = object
    case kind*: DeliKind
    of dkNone:         none:        bool
    of dkIdentifier:   id*:         string
    of dkPath,
       dkStrBlock,
       dkStrLiteral,
       dkString:       strVal*:     string
    of dkRegex:        pattern*:    string
    of dkStream,
       dkError,
       dkSignal,
       dkYear, dkMonth, dkDay,
       dkHour, dkMinute, dkSecond,
       dkNanoSecond,
       dkInt10,
       dkInt16,
       dkInt8,
       dkInteger:      intVal*:     int
    of dkDecimal:      decVal*:     Decimal
    of dkBoolean:      boolVal*:    bool
    of dkVariable:     varName*:    string
    of dkInvocation:   cmd*:        string
    of dkObject,
       dkRan:          table*:      OrderedTable[string, DeliValue]
    of dkDateTime:     dtVal*:      DateTime
    of dkArgShort,
       dkArgLong,
       dkArg:          argName*:    string
    of dkIterable:     generator*:  DeliGenerator
    of dkArray:        values*:     seq[DeliValue]
    else:
      discard

  DeliNodeObj* = object
    parents: seq[DeliNode]
    sons*: seq[DeliNode]
    case kind*: DeliKind
    of dkNone,
       dkIdentifier,
       dkPath,
       dkStrBlock,
       dkStrLiteral,
       dkString,
       dkRegex,
       dkStream,
       dkError,
       dkSignal,
       dkYear, dkMonth, dkDay,
       dkHour, dkMinute, dkSecond,
       dkNanoSecond,
       dkInt10,
       dkInt16,
       dkInt8,
       dkInteger,
       dkDecimal,
       dkBoolean,
       dkVariable,
       dkInvocation,
       dkObject,
       dkRan,
       dkDateTime,
       dkArgShort,
       dkArgLong,
       #dkArg,
       dkIterable:    value*: DeliValue

    of dkJump,
       dkWhileLoop,
       dkDoLoop,
       dkForLoop,
       dkBreakStmt,
       dkContinueStmt,
       dkConditional,
       dkCondition,
       dkFunctionDef,
       dkElse,
       dkInner,
       dkCode,
       dkStatement,
       dkBlock:
      lineNumber*: int
      list_node*: DeliListNode
    of dkCallable:     function*:   DeliFunction
    of dkScript:       script:      DeliScript
    else:
      discard

converter toDeliValue(node: DeliNode): DeliValue =
  case node.kind
  of dkNone,
     dkIdentifier,
     dkPath,
     dkStrBlock,
     dkStrLiteral,
     dkString,
     dkRegex,
     dkStream,
     dkError,
     dkSignal,
     dkYear, dkMonth, dkDay,
     dkHour, dkMinute, dkSecond,
     dkNanoSecond,
     dkInt10,
     dkInt16,
     dkInt8,
     dkInteger,
     dkDecimal,
     dkBoolean,
     dkVariable,
     dkInvocation,
     dkObject,
     dkRan,
     dkDateTime,
     dkArgShort,
     dkArgLong,
     dkArg,
     dkCallable,
     dkIterable:
    return node.value
  else:
    raise newException(ValueError, "Not a value type")

converter toDeliNode(value: DeliValue): DeliNode =
  case value.kind
  of dkNone,
     dkIdentifier,
     dkPath,
     dkStrBlock,
     dkStrLiteral,
     dkString,
     dkRegex,
     dkStream,
     dkError,
     dkSignal,
     dkYear, dkMonth, dkDay,
     dkHour, dkMinute, dkSecond,
     dkNanoSecond,
     dkInt10,
     dkInt16,
     dkInt8,
     dkInteger,
     dkDecimal,
     dkBoolean,
     dkVariable,
     dkInvocation,
     dkObject,
     dkRan,
     dkDateTime,
     dkArgShort,
     dkArgLong,
     dkArg,
     dkCallable,
     dkIterable:
    result.kind = value.kind
    result.value = value
  else:
    return DeliNode(kind: dkNone)

proc todo*(msg: varargs[string, `$`])
proc name*(kind: DeliKind): string =
  return ($kind).substr(2)

let None0 = DeliNode(kind: dkNone)

proc `parent=`*(node: DeliNode, parent: DeliNode) =
  while node.parents.len > 0:
    discard node.parents.pop()
  node.parents.add parent

proc parent*(node: DeliNode): DeliNode =
  if node.parents.len == 0:
    return None0
  return node.parents[0]

proc root*(node: DeliNode): DeliNode =
  result = node
  while result.parent.kind != dkNone:
    result = result.parent

proc script*(node: DeliNode): DeliScript =
  if node.kind == dkScript:
    return node.script
  else:
    if node.parent.kind != dkNone:
      return script(node.parent)
  todo node.kind.name, ".script"
  return nil

proc `script=`*(node: DeliNode, scr: DeliScript) =
  case node.kind
  of dkScript:
    node.script = scr
  of dkNone:
    discard
  else:
    todo "assign ", node.kind.name, ".script"

proc `line=`*(node: DeliNode, line: int) =
  case node.kind
  of dkJump,
     dkWhileLoop,
     dkDoLoop,
     dkForLoop,
     dkBreakStmt,
     dkContinueStmt,
     dkConditional,
     dkCondition,
     dkFunctionDef,
     dkElse,
     dkInner,
     dkCode,
     dkStatement,
     dkBlock:
    node.lineNumber = line
  else: discard

proc line*(node: DeliNode): int =
  case node.kind
  of dkJump,
     dkWhileLoop,
     dkDoLoop,
     dkForLoop,
     dkBreakStmt,
     dkContinueStmt,
     dkConditional,
     dkCondition,
     dkFunctionDef,
     dkElse,
     dkInner,
     dkCode,
     dkStatement,
     dkBlock:
    return node.lineNumber
  else:
    return node.parent.line

const toTbl* = toOrderedTable[string, DeliNode]

proc isNone*(node: DeliNode):bool =
  if node.kind == dkNone:
    return true
  return false

include ./[
  initializers,
  formatters,
  printers,
]
