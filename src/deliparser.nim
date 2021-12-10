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
  node_stack:   Stack[DeliNode]
  entry_point:  DeliNode
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

proc popCapture(parser: Parser): string =
  result = parser.captures.pop()
  echo parser.indent("POPCAP "), result

proc parseStreamInt(str: string): int =
  case str
  of "in":  return 0
  of "out": return 1
  of "err": return 2

proc parseCapture(node: DeliNode, capture: string) =
  case node.kind
  of dkString:     node.strVal  = capture
  of dkPath:       node.strVal  = capture
  of dkIdentifier: node.id      = capture
  of dkVariable:   node.varName = capture
  of dkInvocation: node.cmd     = capture
  of dkBoolean:    node.boolVal = capture == "true"
  of dkStream:     node.intVal  = parseStreamInt(capture)
  of dkInteger:    node.intVal  = parseInt(capture)
  of dkArgShort:   node.argName = capture
  of dkArgLong:    node.argName = capture
  else:
    discard

proc parseCapture(parser: Parser, start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    parser.captures.push(matchStr)
    echo "\27[1;33m", parser.indent("capture: "), "\27[4m", matchStr.replace("\n","\\n"), "\27[0m"

    let node = parser.node_stack.pop()
    node.parseCapture(s[ start .. start+length-1 ])
    parser.node_stack.push(node)

proc initParser(parser: Parser) =
  parser.captures     = Stack[string]()
  parser.symbol_stack = Stack[string]()

proc initLineNumbers(parser: Parser) =
  parser.line_numbers = @[0]
  for offset in parser.line_offsets():
    parser.line_numbers.add(offset)
  echo parser.line_numbers

proc parse*(parser: Parser): int =
  parser.initParser()
  parser.initLineNumbers()

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
          let k = parseEnum[DeliKind]("dk" & p.nt.name)
          parser.node_stack.push(DeliNode(kind: k, line: parser.line_number(start)))
          echo "\27[1;30m", parser.indent("> "), p.nt.name, ": \27[0;34m", s.substr(start).split("\n")[0], "\27[0m"
          parser.symbol_stack.push(p.nt.name)
      leave:
        if p.nt.name notin ["Blank", "VLine", "Comment"]:
          let inner_node = parser.node_stack.pop()
          let symbol = parser.symbol_stack.pop()
          if length > 0:
            let matchStr = s.substr(start, start+length-1)
            echo parser.indent("\27[1m< "), p, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"

            if parser.node_stack.len() > 0:
              var outer_node = parser.node_stack.pop()
              outer_node.sons.add( inner_node )
              parser.entry_point = outer_node
              parser.node_stack.push(outer_node)

            #let line = parser.line_number(start)
            ##echo start, " :",  line

  parser.parsed_len = peg_parser(parser.source)
  return parser.parsed_len

proc getLine*(parser: Parser, line: int): string =
  let start = parser.line_numbers[line]
  let endl  = parser.line_numbers[line+1]
  return parser.source[start .. endl-2]

proc getScript*(parser: Parser): DeliNode =
  return parser.entry_point

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent(toString(son), 4*level)
    printSons(son, level+1)

proc printEntryPoint*(parser: Parser) =
  echo "\n== Node Stack =="
  printSons(parser.entry_point, 0)
