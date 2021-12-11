import std/tables
import deligrammar

### AST representation
grammarToEnum(@["String","None","Ran"])

type
  Argument* = ref object
    short_name*, long_name* : string
    value*: DeliNode

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
  of dkArg,
     dkArgShort,
     dkArgLong:    $(node.argName)
  of dkObject:     $(node.table)
  else: ""

proc `$`*(node: DeliNode): string =
  let value = node.toString()
  if value == "":
    return ($(node.kind)).substr(2)
  else:
    return ($(node.kind)).substr(2) & " " & value


proc `$`*(arg: Argument): string =
  result = ""
  if arg.short_name != "":
    result &= " -" & arg.short_name
  if arg.long_name != "":
    result &= " --" & arg.long_name
  #if ( arg.short_name != "" or arg.long_name != "" ) and arg.value != nil:
  result &= " = "
  if arg.value != nil:
    result &= $(arg.value)

proc isNone*(arg: Argument):bool =
  return arg.short_name == "" and arg.long_name == "" and arg.value.isNone()

proc isFlag*(arg: Argument):bool =
  return arg.short_name != "" or arg.long_name != ""

