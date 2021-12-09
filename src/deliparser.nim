import std/tables
import std/deques
import strutils
import stacks
import pegs
import deliast
import deligrammar

type Parser* = ref object
  source*:      string
  captures:     Stack[string]
  symbol_stack: Stack[string]
  stack_table:  Table[string, Stack[DeliNode]]
  line_numbers: seq[int]
  parsed_len:   int

iterator line_offsets(parser: Parser): int =
  var start = 0
  let length = parser.source.len()
  while start < length:
    yield start
    start = parser.source.find("\n", start) + 1

proc line_number(parser: Parser, pos: int): int =
  for line, offset in parser.line_numbers:
    if offset > pos:
      return line - 1

proc indent(parser: Parser, msg: string): string =
  return indent( msg, 4*parser.symbol_stack.len() )

proc parseCapture(parser: Parser, start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    parser.captures.push(matchStr)
    echo "\27[1;33m", parser.indent("capture: "), "\27[4m", matchStr.replace("\n","\\n"), "\27[0m"

proc pushNode(parser: Parser, symbol: string, node: DeliNode) =
  var stack = addr parser.stack_table[symbol]
  stack[].push(node)
  echo parser.indent("PUSH "), symbol, " = ", stack[].len()

proc popCapture(parser: Parser): string =
  result = parser.captures.pop()
  echo parser.indent("POPCAP "), result

proc parseStreamInt(str: string): int =
  case str
  of "in":  return 0
  of "out": return 1
  of "err": return 2

proc newNode(parser: Parser, symbol: string, line: int): DeliNode =
  result = case symbol
  of "StrLiteral",
     "StrBlock":   DeliNode(line: line, kind: dkString,    strVal: parser.popCapture())
  of "Path":       DeliNode(line: line, kind: dkPath,      strVal: parser.popCapture())
  of "Identifier": DeliNode(line: line, kind: dkIdentifier,    id: parser.popCapture())
  of "Variable":   DeliNode(line: line, kind: dkVariable, varName: parser.popCapture())
  of "Invocation": DeliNode(line: line, kind: dkInvocation,   cmd: parser.popCapture())
  of "Boolean":    DeliNode(line: line, kind: dkBoolean,  boolVal: parser.popCapture() == "true")
  of "Stream":     DeliNode(line: line, kind: dkStream,    intVal: parseStreamInt(parser.popCapture()))
  of "Integer":    DeliNode(line: line, kind: dkInteger,   intVal: parseInt(parser.popCapture()))
  of "Arg":        DeliNode(line: line, kind: dkArg)
  of "ArgShort":   DeliNode(line: line, kind: dkArgShort, argName: parser.popCapture())
  of "ArgLong":    DeliNode(line: line, kind: dkArgLong,  argName: parser.popCapture())
  else:
    let k = parseEnum[DeliKind]("dk" & symbol)
    DeliNode(kind: k, line: line)

proc parse*(parser: Parser): int =
  parser.captures     = Stack[string]()
  parser.symbol_stack = Stack[string]()
  parser.stack_table  = initTable[string, Stack[DeliNode]]()
  for symbol in symbol_names:
    parser.stack_table[symbol] = Stack[DeliNode]()

  parser.line_numbers = @[0]
  for offset in parser.line_offsets():
    parser.line_numbers.add(offset)
  echo parser.line_numbers

  let grammar = peg(grammar_source)
  let peg_parser = grammar.eventParser:
    pkCapture:
      leave:
        parser.parseCapture(start, length, s)
    pkCapturedSearch:
      leave:
        case parser.symbol_stack.peek()
        of "StrBlock":
          parser.parseCapture(start, length-3, s)
        else:
          parser.parseCapture(start, length-1, s)
    pkNonTerminal:
      enter:
        if p.nt.name notin ["Blank", "VLine", "Comment"]:
          echo "\27[1;30m", parser.indent("> "), p.nt.name, ": \27[0;34m", s.substr(start).split("\n")[0], "\27[0m"
          parser.symbol_stack.push(p.nt.name)
      leave:
        if p.nt.name notin ["Blank", "VLine", "Comment"]:
          let symbol = parser.symbol_stack.pop()
          if length > 0:
            let matchStr = s.substr(start, start+length-1)
            echo parser.indent("\27[1m< "), p, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"

            let parent = if parser.symbol_stack.len() > 0:
              parser.symbol_stack.peek()
            else: "Script"

            let line = parser.line_number(start)
            #echo start, " :",  line
            let node = parser.newNode(symbol, line)

            for son in parser.stack_table[symbol].toSeq():
              node.sons.add( son )
            parser.stack_table[symbol].clear()
            parser.pushNode(parent, node)

  parser.parsed_len = peg_parser(parser.source)
  return parser.parsed_len

proc getLine*(parser: Parser, line: int): string =
  let start = parser.line_numbers[line]
  let endl  = parser.line_numbers[line+1]
  return parser.source[start .. endl-2]

proc getScript*(parser: Parser): DeliNode =
  return DeliNode(kind: dkScript, sons: parser.stack_table["Script"].toSeq())

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent(toString(son), 4*level)
    printSons(son, level+1)

proc printStackTable*(parser: Parser) =
  echo "\n== Stack Table =="
  for k,v in parser.stack_table:
    echo k, "="
    for node in v.toSeq():
      printSons(node, 0)
      #echo "  ", node[], " sons = ", node[].sons.len()

