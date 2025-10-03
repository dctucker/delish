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

type
  DeliNode* = ref DeliNodeObj
  DeliList* = SinglyLinkedList[DeliNode]
  DeliListNode* = SinglyLinkedNode[DeliNode]
  DeliTable* = OrderedTable[string, DeliNode]
  DeliFastTable* = Table[string, DeliNode]

  Decimal* = object
    whole*, fraction*, decimals*: int

  Iterable* = iterator(iter: DeliNode): DeliNode
  DeliFunction* = proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.}

  DeliNodeObj* = object
    parents: seq[DeliNode]
    sons*: seq[DeliNode]
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
    of dkDateTime:     dtVal*:      DateTime
    of dkArgShort,
       dkArgLong,
       dkArg:          argName*:    string
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
    of dkIterable:     generator*:  Iterable
    of dkCallable:     function*:   DeliFunction
    else:
      discard
    script*:     DeliScript

let None0 = DeliNode(kind: dkNone)

proc `parent=`*(node: DeliNode, parent: DeliNode) =
  while node.parents.len > 0:
    discard node.parents.pop()
  node.parents.add parent

proc parent*(node: DeliNode): DeliNode =
  if node.parents.len == 0:
    return None0
  return node.parents[0]

# TODO temporary fix
proc findScript*(node: DeliNode): DeliScript =
  if node.script != nil:
    return node.script
  return node.parent.findScript

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
