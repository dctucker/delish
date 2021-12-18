#import std/tables
#import std/deques
#import macros
import strutils
import stacks
#import pegs
import deliast
import deligrammar


type Parser* = ref object
  source*:      string
  debug*:       bool
  captures:     Stack[string]
  symbol_stack: Stack[string]
  node_stack:   Stack[DeliNode]
  entry_point:  DeliNode
  line_numbers: seq[int]
  parsed_len:   int

proc packcc_main*(input: cstring, len: cint, parser: Parser): cint {.importc.}

proc debug(parser: Parser, msg: varargs[string]) =
  if not parser.debug:
    return
  for m in msg:
    stdout.write(m)
  stdout.write("\n")

iterator line_offsets(parser: Parser): int =
  var start = 0
  let length = parser.source.len()
  while start < length:
    yield start
    start = parser.source.find("\n", start) + 1

proc line_number*(parser: Parser, pos: int): int =
  for line, offset in parser.line_numbers:
    if offset > pos:
      return line - 1

proc indent(parser: Parser, msg: string): string =
  return indent( msg, 4*parser.symbol_stack.len() )

#proc popCapture(parser: Parser): string =
#  result = parser.captures.pop()
#  debug(parser, parser.indent("POPCAP "), result)

proc parseStreamInt(str: string): int =
  case str
  of "in":  return 0
  of "out": return 1
  of "err": return 2
  else:
    return str.parseInt()

proc parseCapture(node: DeliNode, capture: string) =
  case node.kind
  of dkStrLiteral,
     dkStrBlock,
     dkString:     node.strVal  = capture
  of dkPath:       node.strVal  = capture
  of dkIdentifier: node.id      = capture
  of dkVariable:   node.varName = capture
  of dkInvocation:
    if node.cmd == "":
      node.cmd     = capture
    else:
      node.sons.add(DeliNode(kind:dkString, strVal: capture))
  of dkBoolean:    node.boolVal = capture == "true"
  #of dkStream:     node.intVal  = parseStreamInt(capture)
  of dkInteger:    node.intVal  = parseInt(capture)
  of dkArgShort:   node.argName = capture
  of dkArgLong:    node.argName = capture
  else:
    todo "capture failed for ", $(node.kind), " '", capture, "'"

proc parseCapture(parser: Parser, start, length: int, s: string) =
  if length >= 0:
    let matchStr = s.substr(start, start+length-1)
    parser.captures.push(matchStr)
    debug parser, "\27[1;33m", parser.indent("capture: "), "\27[4m", matchStr.replace("\n","\\n"), "\27[0m"

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
  #parser.debug parser.line_numbers


#proc echoItems(p: Peg) =
#  for item in p.items():
#    echo item.kind, item
#    echoItems(item)

#let grammar = peg(getGrammar())

proc assimilate(inner, outer: DeliNode) =
  if outer.kind == dkStream:
    outer.intVal = case inner.kind
      of dkStreamIn:  0
      of dkStreamOut: 1
      of dkStreamErr: 2
      else: -1

#import std/marshal
proc parse*(parser: Parser): int =
  parser.initParser()
  parser.initLineNumbers()

  var cstr = parser.source.cstring
  let y = packcc_main(cstr, parser.source.len.cint, parser)

  #echo "=== Grammar ==="
  #echo grammar.repr
  #echo "=== /Grammar ==="

  #let serial = $$grammar
  #echo serial

  #parser.parsed_len = peg_parser(parser.source)
  return parser.parsed_len

proc enter*(parser: Parser, k: DeliKind, pos: int, matchStr: string) =
  parser.node_stack.push(DeliNode(kind: k, line: parser.line_number(pos)))
  debug parser, "\27[1;30m", parser.indent("> "), $k, ": \27[0;34m", matchStr.split("\n")[0], "\27[0m"
  parser.symbol_stack.push($k)

proc leave*(parser: Parser, k: DeliKind, pos: int, matchStr: string) =
  let inner_node = parser.node_stack.pop()
  discard parser.symbol_stack.pop()
  if matchStr.len > 0:
    debug parser, parser.indent("\27[1m< "), $k, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"

    if parser.node_stack.len() > 0:
      var outer_node = parser.node_stack.pop()
      outer_node.sons.add( inner_node )
      assimilate(inner_node, outer_node)
      parser.entry_point = outer_node
      parser.node_stack.push(outer_node)


    #let line = parser.line_number(start)
    ##debug start, " :",  line

  #let peg_parser = grammar.eventParser:
  #  pkCapture:
  #    leave:
  #      parser.parseCapture(start, length, s)
  #  pkCapturedSearch:
  #    leave:
  #      case parser.symbol_stack.peek()
  #      of "StrBlock":
  #        parser.parseCapture(start, length-3, s)
  #      else:
  #        parser.parseCapture(start, length-1, s)
  #  pkNonTerminal:
  #    enter:
  #      if p.nt.name notin ["Blank", "VLine", "Comment"]:
  #        let k = parseEnum[DeliKind]("dk" & p.nt.name)
  #        parser.node_stack.push(DeliNode(kind: k, line: parser.line_number(start)))
  #        debug parser, "\27[1;30m", parser.indent("> "), p.nt.name, ": \27[0;34m", s.substr(start).split("\n")[0], "\27[0m"
  #        parser.symbol_stack.push(p.nt.name)
  #    leave:
  #      if p.nt.name notin ["Blank", "VLine", "Comment"]:
  #        let inner_node = parser.node_stack.pop()
  #        discard parser.symbol_stack.pop()
  #        if length > 0:
  #          let matchStr = s.substr(start, start+length-1)
  #          debug parser, parser.indent("\27[1m< "), $p, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"

  #          if parser.node_stack.len() > 0:
  #            var outer_node = parser.node_stack.pop()
  #            outer_node.sons.add( inner_node )
  #            assimilate(inner_node, outer_node)
  #            parser.entry_point = outer_node
  #            parser.node_stack.push(outer_node)

  #          #let line = parser.line_number(start)
  #          ##debug start, " :",  line


proc getLine*(parser: Parser, line: int): string =
  let start = parser.line_numbers[line]
  let endl  = parser.line_numbers[line+1]
  return parser.source[start .. endl-2]

proc getScript*(parser: Parser): DeliNode =
  return parser.entry_point

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent($son, 4*level)
    printSons(son, level+1)

proc printEntryPoint*(parser: Parser) =
  echo "\n== Node Stack =="
  printSons(parser.entry_point, 0)




## PackCC integration stuff

type PackEvent = enum
  peEvaluate, peMatch, peNoMatch

proc something*(kind: cint, str: cstring, len: cint): cint {.exportc.} =
  result = kind
  let k = DeliKind(kind)
  echo $k, " ", str

type DeliT = object
  input: cstring
  offset: csize_t
  length: csize_t
  parser: Parser

proc deli_event(pauxil: pointer, event: cint, rule: cint, level: cint, pos: csize_t, buffer: cstring, length: csize_t) {.exportc.} =
  case rule
  of dkS.ord, dkW.ord, dkU.ord, dkBlank.ord, dkVLine.ord, dkComment.ord: return
  else: discard

  var e = ""
  var capture = ""

  var aux = cast[ptr DeliT](pauxil)
  var parser = aux.parser

  parser.parsed_len = max(parser.parsed_len, pos.int)

  case event
    of peEvaluate.ord:
      e = "> "
      parser.enter( DeliKind(rule), pos.int, capture )
    of peMatch.ord:
      e = "\27[1m< "
      capture = newString(length)
      if length > 0:
        for i in 0 .. length - 1:
          capture[i] = buffer[i].char
      parser.leave( DeliKind(rule), pos.int, capture )
    of peNoMatch.ord:
      e = "< "
      parser.leave( DeliKind(rule), pos.int, capture )
    else: e = "  "

  #let k = DeliKind(rule)
  #echo indent(e, level * 2), $k, " ", capture.split("\n")[0], "\27[0m"

{.compile: "packcc.c" .}
