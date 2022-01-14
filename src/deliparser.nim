#import std/tables
#import std/deques
#import macros
import strutils
import stacks
#import pegs
import deliast
#import deligrammar


type Parser* = ref object
  source*:      string
  debug*:       int
  captures:     Stack[string]
  symbol_stack: Stack[string]
  node_stack:   Stack[DeliNode]
  entry_point:  DeliNode
  nodes:        seq[DeliNode]
  line_numbers: seq[int]
  parsed_len:   int

proc packcc_main*(input: cstring, len: cint, parser: Parser): cint {.importc.}

proc debug(parser: Parser, msg: varargs[string]) =
  if parser.debug == 0:
    return
  for m in msg:
    stdout.write(m)
  stdout.write("\n")

proc debug_tree(parser: Parser, msg: varargs[string]) =
  if parser.debug < 2:
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

proc assimilate(inner, outer: DeliNode) =
  if outer.kind == dkStream:
    outer.intVal = case inner.kind
      of dkStreamIn:  0
      of dkStreamOut: 1
      of dkStreamErr: 2
      else: -1

proc parse*(parser: Parser): int =
  parser.initParser()
  parser.initLineNumbers()

  var cstr = parser.source.cstring
  parser.nodes = @[deliNone()]
  let y = packcc_main(cstr, parser.source.len.cint, parser)
  parser.entry_point = parser.nodes[^1]

  return parser.parsed_len

proc enter*(parser: Parser, k: DeliKind, pos: int, matchStr: string) =
  parser.node_stack.push(DeliNode(kind: k, line: parser.line_number(pos)))
  debug parser, "\27[1;30m", parser.indent("> "), $k, ": \27[0;34m", matchStr.split("\n")[0], "\27[0m"
  parser.symbol_stack.push($k)
  #echo "\27[31m", $parser.node_stack, "\27[0m"

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
  else:
    debug parser, parser.indent("\27[30;1m< "), $k, "\27[0m"

  #echo "\27[31m", $parser.node_stack, "\27[0m"

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

proc parseCapture(parser: Parser, rstart, rend: csize_t, buffer: cstring): DeliNode {.exportc.} =
  let length = rend - rstart
  var capture = newString(length)
  if length > 0:
    for i in 0 .. length - 1:
      capture[i] = buffer[i].char
  debug_tree parser, "CAPTURE ", capture
  #parser.parseCapture(rstart.int, length.int, capture)

proc nodeString(parser: Parser, kind: DeliKind, rstart, rend: csize_t, buffer: cstring): cint {.exportc.} =
  result = parser.nodes.len.cint
  var node = DeliNode(kind: kind)

  let length = rend - rstart
  var capture = newString(length)
  if length > 0:
    for i in 0 .. length - 1:
      capture[i] = buffer[i].char

  debug_tree parser, $result, " nodeString ", $kind, " \"", capture, "\""
  node.parseCapture(capture)

  parser.nodes.add(node)

proc getNode(parser: Parser, i: cint): DeliNode =
  result = if i.int <= 0: deliNone() else: parser.nodes[i.int]

#proc createNode(parser: Parser, kind: DeliKind, ints: varargs[cint]): cint {.exportc.} =
#  result = parser.nodes.len.cint
#  debug parser, "createNode ", $kind
#  let node = DeliNode(kind: kind, sons: @[])
#
#  for i in ints:
#    let son = parser.getNode(i)
#    node.sons.add(son)
#  parser.nodes.add(node)

proc createNode0(parser: Parser, kind: DeliKind): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug_tree parser, $result, " createNode0 ", $kind
  let node = DeliNode(kind: kind)
  parser.nodes.add(node)

proc createNode1(parser: Parser, kind: DeliKind, s1: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug_tree parser, $result, " createNode1 ", $kind, " ", $s1
  let node = DeliNode(kind: kind, sons: @[])

  let son1 = parser.getNode(s1)
  node.sons.add(son1)

  parser.nodes.add(node)

proc createNode2(parser: Parser, kind: DeliKind, s1, s2: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug_tree parser, $result, " createNode2 ", $kind, " ", $s1, " ", $s2
  var node = DeliNode(kind: kind, sons: @[])

  let son1 = parser.getNode(s1)
  node.sons.add(son1)
  let son2 = parser.getNode(s2)
  node.sons.add(son2)

  parser.nodes.add(node)

proc createNode3(parser: Parser, kind: DeliKind, s1, s2, s3: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug_tree parser, $result, " createNode3 ", $kind, " ", $s1, " ", $s2, " ", $s3
  var node = DeliNode(kind: kind, sons: @[])

  let son1 = parser.getNode(s1)
  node.sons.add(son1)
  let son2 = parser.getNode(s2)
  node.sons.add(son2)
  let son3 = parser.getNode(s3)
  node.sons.add(son3)

  parser.nodes.add(node)

proc nodeAppend(parser: Parser, p, s: cint): cint {.exportc.} =
  let son = parser.getNode(s)
  debug_tree parser, $p, " nodeAppend ", $son.kind, " ", $s
  parser.getNode(p).sons.add(son)
  result = p

proc setLine(parser: Parser, n: cint, l: cint): cint {.exportc.} =
  debug_tree parser, $n, " setLine ", $l
  var node = parser.getNode(n)
  node.line = parser.line_number(l.int)
  parser.nodes[n] = node

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
