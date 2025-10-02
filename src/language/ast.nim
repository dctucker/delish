import std/[
  lists,
  tables,
  strutils,
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
       dkConditional,
       dkForLoop:      list_node*:  DeliListNode
    of dkIterable:     generator*:  Iterable
    of dkCallable:     function*:   DeliFunction
    else:
      discard
    sons*: seq[DeliNode]
    line*: int
    script*:     DeliScript

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

