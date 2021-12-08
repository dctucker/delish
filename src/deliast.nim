import deligrammar

### AST representation
grammarToEnum(@["String","None"])

type
  DeliNode* = ref object
    case kind*: DeliKind
    of dkNone:         none:        bool
    of dkIdentifier:   id*:         string
    of dkString:       strVal*:     string
    of dkInteger:      intVal*:     int
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

proc deliNone*(): DeliNode =
  return DeliNode(kind: dkNone, none: true)

proc toString*(node: DeliNode): string =
  result = case node.kind
  of dkIdentifier: node.id
  of dkString:     node.strVal
  of dkInteger:    $(node.intVal)
  of dkBoolean:    $(node.boolVal)
  of dkVariable:   $(node.varName)
  of dkArg,
     dkArgShort,
     dkArgLong:    $(node.argName)
  else:            "[" & $(node.kind) & "]"


#when isMainModule:
#  import strutils
#
#  proc parseTokens(str: string): DeliNode =
#    let tokens = splitWhitespace(str)
#    for token in tokens:
#      if token.startsWith("$"):
#        return DeliNode(kind: dkVariable, name: token[1 .. ^1])
#      if token.startsWith('"') or token.startsWith("'"):
#        return DeliNode(kind: dkString, strVal: token[1 .. ^2])
#      if token =~ peg"'true' / 'false'":
#        return DeliNode(kind: dkBoolean, boolVal: token == "true")
#      if token =~ peg"\d+":
#        return DeliNode(kind: dkInteger, intVal: token.parseInt)
#      return DeliNode(kind: dkNone)
#
#  import os
#  if paramCount() < 1:
#    echo "usage: delish script.deli"
#    quit 2
#
#  let source = readFile(paramStr(1))
#
#  var statement = ""
#  let lines = splitLines(source)
#  for line in lines:
#    if line.startsWith("#"):
#      continue
#    if line.endsWith("\\"):
#      statement &= line[0 .. ^2]
#      continue
#    statement &= line
#
#    if statement.len == 0:
#      continue
#
#    var node = DeliNode(kind: dkNone, none: true)
#    let tokens = splitWhitespace(statement)
#    for i, token in tokens:
#      if node.kind == dkNone:
#        case token
#        of "arg":
#          node = DeliNode(kind: dkArgStmt)
#          continue
#
#      case node.kind
#      of dkArgStmt:
#        if token.startsWith("--"):
#          node.long_name = token
#        elif token.startsWith("-"):
#          node.short_name = token
#        elif token == "=":
#          node.default_value = parseTokens(join(tokens[i+1 .. ^1], " "))
#          break
#      else:
#        continue
#
#    stdout.writeLine("Statement ", node[])
#    statement = ""
#
#
#  #var line_out = ""
#  #let lines = map( splitLines(source), proc(line: string): string =
#  #  if line.endsWith("\\"):
#  #    line_out &= line[0 .. ^2]
#  #    return
#  #  else:
#  #    line_out &= line
#  #
#  #  var ret = line_out
#  #  line_out = ""
#  #  return ret
#  #)
