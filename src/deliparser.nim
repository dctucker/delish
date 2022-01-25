import strutils
import stacks
import deliast
import deliscript


type Parser* = ref object
  debug*:       int
  parsed_len*:  int
  entry_point:  DeliNode
  script*:      DeliScript
  symbol_stack: Stack[DeliKind]
  nodes:        seq[DeliNode]

proc packcc_main(input: cstring, len: cint, parser: Parser): cint {.importc.}

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

proc indent(parser: Parser, msg: string): string =
  return indent( msg, 4*parser.symbol_stack.len() )

proc initParser(parser: Parser) =
  parser.symbol_stack = Stack[DeliKind]()

proc parse*(parser: Parser): DeliNode =
  parser.initParser()

  var cstr = parser.script.source.cstring
  parser.nodes = @[deliNone()]
  discard packcc_main(cstr, parser.script.source.len.cint, parser)
  parser.entry_point = parser.nodes[^1]
  parser.entry_point.script = parser.script
  return parser.entry_point

proc enter(parser: Parser, k: DeliKind, pos: int, matchStr: string) =
  debug parser, "\27[1;30m", parser.indent("> "), $k, ": \27[0;34m", matchStr.split("\n")[0], "\27[0m"
  parser.symbol_stack.push(k)

proc leave(parser: Parser, k: DeliKind, pos: int, matchStr: string) =
  discard parser.symbol_stack.pop()
  if matchStr.len > 0:
    debug parser, parser.indent("\27[1m< "), $k, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"
  else:
    debug parser, parser.indent("\27[30;1m< "), $k, "\27[0m"

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent($son, 4*level)
    printSons(son, level+1)


## PackCC integration stuff

type PackEvent = enum
  peEvaluate, peMatch, peNoMatch

type DeliT = object
  input: cstring
  offset: csize_t
  length: csize_t
  parser: Parser

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
  #case son.kind
  #of dkPair:
  #  var k = son.sons[0]
  #  var v = son.sons[1]
  #  (parser.getNode(p).table)[k.toString] = v
  #else:
  parser.getNode(p).sons.add(son)
  result = p

proc setLine(parser: Parser, n: cint, l: cint): cint {.exportc.} =
  debug_tree parser, $n, " setLine ", $l
  var node = parser.getNode(n)
  node.line = parser.script.line_number(l.int)
  node.script = parser.script
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
