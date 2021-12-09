import deligrammar

### AST representation
grammarToEnum(@["String","None","Ran"])

type
  DeliNode* = ref object
    case kind*: DeliKind
    of dkNone:         none:        bool
    of dkIdentifier:   id*:         string
    of dkPath,
       dkString:       strVal*:     string
    of dkStream,
       dkInteger:      intVal*:     int
    of dkBoolean:      boolVal*:    bool
    of dkVariable:     varName*:    string
    of dkInvocation:   cmd*:        string
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

proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)

proc toString*(node: DeliNode): string =
  let value = case node.kind
  of dkIdentifier: node.id
  of dkPath,
     dkString:     node.strVal
  of dkStream,
     dkInteger:    $(node.intVal)
  of dkBoolean:    $(node.boolVal)
  of dkVariable:   $(node.varName)
  of dkInvocation: node.cmd
  of dkArg,
     dkArgShort,
     dkArgLong:    $(node.argName)
  else: ""
  if value == "":
    return ($(node.kind)).substr(2)
  else:
    return ($(node.kind)).substr(2) & " " & value

