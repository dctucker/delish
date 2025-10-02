import std/[
  os,
  strutils,
  tables,
]
import ./ast
import ../stacks
import ../deliscript
import ../delitypes/parse
import ../errors

const deepDebug {.booldefine.}: bool = false

type
  Auxil* = object
    input: cstring
    offset: csize_t
    length: csize_t
    parser: Parser

  #PccCharArray  {.final,incompleteStruct.} = object
  #PccLrTable    {.final,incompleteStruct.} = object
  #PccLrStack    {.final,incompleteStruct.} = object
  #PccThunkArray {.final,incompleteStruct.} = object

  ContextTag = ref object
    pos: csize_t    # the position in the input of the first character currently buffered
    cur: csize_t    # the current parsing position in the character buffer
    level: csize_t
    #buffer: PccCharArray
    #lrtable: PccLrTable
    #lrstack: PccLrStack
    #thunks: PccThunkArray
    #auxil: Auxil

  ErrorMsg = object
    pos*: int
    msg*: string

  Metric = object
    evaluate: int
    noMatch:  int
    match:    int

  Parser* = ref object
    debug*:       int
    slowmo*:      bool
    parsed_len*:  int
    next_pos:     int
    script*:      DeliScript
    symbol_stack: Stack[DeliKind]
    brackets:     Stack[char]
    nodes:        seq[DeliNode]
    errors*:      seq[ErrorMsg]
    metrics:      OrderedTable[DeliKind,Metric]
    max_depth:    int
    context:      pointer
    auxil:        ptr Auxil

proc contextTag(parser: Parser): ContextTag =
  return cast[ContextTag](parser.context)

template debug(level: int, code: untyped) =
  if parser.debug >= level:
    code

proc indent(parser: Parser, msg: string): string =
  return indent( msg, 4*parser.symbol_stack.len() )

proc total*(m: Metric): int =
  return m.match + m.noMatch + m.evaluate

proc printMetric(m: Metric, name: string) =
  stderr.write name.alignLeft(13)
  stderr.write ($m.evaluate).align(8)
  stderr.write ($m.noMatch).align(8)
  stderr.write ($m.match).align(8)
  stderr.write ($m.total).align(8)
  stderr.write "\n"

proc printMetrics*(parser: Parser) =
  stderr.write "Kind             Eval  NoMatch   Match   Total\n"
  parser.metrics.sort(proc(a,b: (DeliKind, Metric)): int = cmp(b[1].total, a[1].total))
  var total: Metric
  for k,m in parser.metrics:
    m.printMetric k.name
    total.evaluate += m.evaluate
    total.noMatch += m.noMatch
    total.match += m.match
  total.printMetric "Total"
  stderr.write "Maximum depth: ", parser.max_depth, "\n"


proc deli_create(auxil: var Auxil): pointer {.importc.}
proc deli_setup(p: Parser, str: cstring, l: csize_t): pointer {.importc.}
proc deli_parse(ctx: pointer, ret: pointer): cint {.importc.}
proc deli_destroy(ctx: pointer): void {.importc.}

proc parse_from_offset(parser: Parser, offset: csize_t) =
  parser.contextTag.pos = offset
  while deli_parse(parser.context, nil) > 0:
    discard

proc initParser(parser: Parser) =
  parser.symbol_stack.clear
  parser.brackets.clear
  parser.errors = @[]
  parser.metrics.clear
  parser.parsed_len = 0

  var input = parser.script.source.cstring
  #parser.auxil = Auxil(
  #  input: input,
  #  offset: 0,
  #  length: parser.script.source.len.csize_t,
  #  parser: parser,
  #)
  #parser.context = deli_create(parser.auxil)
  parser.context = deli_setup(parser, input, parser.script.source.len.csize_t)

iterator parse*(parser: Parser): DeliNode =
  parser.initParser()

  while parser.next_pos < parser.script.source.len:
    parser.nodes = @[deliNone()]
    try:
      parser.parse_from_offset(parser.next_pos.csize_t)
      if parser.brackets.len > 0:
        let b = parser.brackets.popUnsafe()
        parser.errors.add(ErrorMsg(pos: parser.script.source.len, msg: "expected closing `" & b & "`"))

      if parser.errors.len > 0:
        break

      yield parser.nodes[^1]
    except ParseError as e:
      break

  parser.parsed_len = parser.next_pos
  deli_destroy(parser.context)

proc parseAll*(parser: Parser): DeliNode =
  result = DeliNode(kind: dkScript)

  for s in parser.parse():
    if parser.errors.len > 0:
      break
    result.sons.add s
    #echo s.repr



proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent($son, 4*level)
    printSons(son, level+1)


## PackCC integration stuff

type PackEvent = enum
  peEvaluate, peMatch, peNoMatch

proc pccError(parser: Parser): void {.exportc.} =
  when deepDebug:
    debug 2:
      stderr.write "\n"
  if parser.errors.len == 0:
    parser.errors.add(ErrorMsg(pos: 0, msg: "Syntax error"))
  raise newException(ParseError, "Syntax error")

proc parseCapture(node: DeliNode, capture: string) =
  case node.kind
  of dkStrLiteral,
     dkStrBlock,
     dkString:     node.strVal  = parseString(capture)
  of dkPath:       node.strVal  = capture
  of dkIdentifier: node.id      = capture
  of dkVariable:   node.varName = capture
  of dkInvocation:
    if node.cmd == "":
      node.cmd     = capture
    else:
      node.sons.add(DeliNode(kind:dkString, strVal: capture))
  of dkBoolean:    node.boolVal = parseBoolean(capture)
  of dkInteger:    node.intVal  = parseInteger(capture)
  of dkDecimal:    node.decVal  = parseDecimal(capture)
  of dkArgShort:   node.argName = capture
  of dkArgLong:    node.argName = capture
  else:
    todo "capture failed for ", $(node.kind), " '", capture, "'"

proc addNode(parser: Parser, node: DeliNode) =
  parser.nodes.add node

proc bracket(parser: Parser, pos: int, c: char, d: int8) {.exportc.} =
  if d > 0:
    parser.brackets.push(c)
  elif d < 1:
    if parser.brackets.len == 0:
      parser.errors.add(ErrorMsg(pos: pos, msg: "Unexpected `" & $c))
      return
    let c1 = parser.brackets.popUnsafe()
    if c1 != c:
      parser.errors.add(ErrorMsg(pos: pos, msg: "Expected `" & $c1 & "`, got `" & $c & "`"))

proc nodeString(parser: Parser, kind: DeliKind, rstart, rend: csize_t, buffer: cstring): cint {.exportc.} =
  result = parser.nodes.len.cint
  var node = DeliNode(kind: kind)

  let length = rend - rstart
  var capture = newString(length)
  if length > 0:
    for i in 0 .. length - 1:
      capture[i] = buffer[i].char

  debug 3:
    stderr.write $result, " nodeString ", $kind, " \"", capture, "\"\n"
  node.parseCapture(capture)

  parser.addNode node

proc getNode(parser: Parser, i: cint): DeliNode =
  result = if i.int <= 0: deliNone() else: parser.nodes[i.int]

proc createNode0(parser: Parser, kind: DeliKind): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode0 ", $kind, "\n"
  let node = DeliNode(kind: kind)
  parser.addNode node

proc createNode1(parser: Parser, kind: DeliKind, s1: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode1 ", $kind, " ", $s1, "\n"
  let node = DeliNode(kind: kind, sons: @[])
  node.sons.add(parser.getNode(s1))
  parser.addNode node

proc createNode2(parser: Parser, kind: DeliKind, s1, s2: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode2 ", $kind, " ", $s1, " ", $s2, "\n"
  var node = DeliNode(kind: kind, sons: @[])
  node.sons.add(parser.getNode(s1))
  node.sons.add(parser.getNode(s2))
  parser.addNode node

proc createNode3(parser: Parser, kind: DeliKind, s1, s2, s3: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode3 ", $kind, " ", $s1, " ", $s2, " ", $s3, "\n"
  var node = DeliNode(kind: kind, sons: @[])
  node.sons.add(parser.getNode(s1))
  node.sons.add(parser.getNode(s2))
  node.sons.add(parser.getNode(s3))
  parser.addNode node

proc nodeAppend(parser: Parser, p, s: cint): cint {.exportc.} =
  let son = parser.getNode(s)
  debug 3:
    stderr.write $p, " nodeAppend ", $son.kind, " ", $s, "\n"
  #case son.kind
  #of dkPair:
  #  var k = son.sons[0]
  #  var v = son.sons[1]
  #  (parser.getNode(p).table)[k.toString] = v
  #else:
  parser.getNode(p).sons.add(son)
  result = p

proc setLine(parser: Parser, dk: cint, l: csize_t): cint {.exportc.} =
  let pos = l - parser.contextTag.pos
  debug 3:
    stderr.write $dk, " setLine ", $l, " (pos=", $pos, ")\n"
  var node = parser.getNode(dk)
  node.line = parser.script.line_number(pos.int)
  node.script = parser.script
  parser.nodes[dk] = node

proc setNextPos(parser: Parser): cint {.exportc.} =
  #parser.next_pos = pos
  #echo "  set next pos ", pos, "-", pos2, " offset = ", parser.auxil.offset

  parser.next_pos = parser.contextTag.cur.int
  #echo parser.contextTag.repr

proc parserError(parser: Parser, pos: csize_t, msg: cstring) {.exportc.} =
  let length = msg.len()
  var errmsg = newString(length)
  for i in 0 .. length - 1:
    errmsg[i] = msg[i].char

  parser.errors.add(ErrorMsg(pos: pos.int, msg: errmsg))

when deepDebug:
  const
    cSave = "\27[s"
    cRest = "\27[u"
    cDark = "\27[1;30m"
    cUnder= "\27[4m"
    cRed  = "\27[31m"
    cToken= "\27[0;34m"
    cNorm = "\27[0m"
    cClear= "\27[J"
    cUp   = "\27[A"
    cDown = "\27[B"

  var lastpos = -1

  proc symbols(parser: Parser): string =
    for k in parser.symbol_stack.toSeq:
      result &= k.name & " "

  proc evaluate(parser: Parser, k: DeliKind, pos: int, matchStr: string) {.inline.} =
    debug 2:
      stderr.write "\r", cSave, pos, cClear, cDark, parser.symbols, cUnder, k.name, cNorm
    parser.symbol_stack.push(k)

    if k notin parser.metrics:
      parser.metrics[k] = Metric(evaluate: 0, noMatch: 0, match: 0)
    parser.metrics[k].evaluate += 1

  proc noMatch(parser: Parser, k: DeliKind, pos: int, matchStr: string) {.inline.} =
    discard parser.symbol_stack.popUnsafe()
    debug 2:
      stderr.write "\r", pos, cDark, parser.symbols, cRed, k.name, cNorm

    parser.metrics[k].noMatch += 1

  proc match(parser: Parser, k: DeliKind, pos: int, matchStr: string) {.inline.} =
    discard parser.symbol_stack.popUnsafe()
    debug 2:
      if pos != lastpos:
        stderr.write "\r", cSave, pos, cClear, cDark, parser.symbols, cNorm, k.name, ": ", cToken, matchStr, cNorm, "\n"
      else:
        stderr.write cRest, pos, cDark, parser.symbols, cNorm, k.name, "\n"
      lastpos = pos

    parser.metrics[k].match += 1


proc deli_event(parser: Parser, event: cint, rule: cint, level: cint, pos: csize_t, buffer: cstring, length: csize_t) {.exportc.} =

  parser.parsed_len = max(parser.parsed_len, pos.int)
  parser.max_depth = max(parser.max_depth, level)

  case rule
  of dkC.ord, dkW.ord, dkU.ord, dkS.ord, dkComment.ord: return
  else: discard

  if parser.debug == 0: return

  when deepDebug:
    var capture = ""

    case event
      of peEvaluate.ord:
        parser.evaluate( DeliKind(rule), pos.int, capture )
      of peMatch.ord:
        capture = newString(length)
        if length > 0:
          for i in 0 .. length - 1:
            capture[i] = buffer[i].char
        parser.match( DeliKind(rule), pos.int, capture )
      of peNoMatch.ord:
        parser.noMatch( DeliKind(rule), pos.int, capture )
      else:
        discard

  debug 2:
    if parser.slowmo:
      sleep(50)

  ##let k = DeliKind(rule)
  ##echo indent(e, level * 2), $k, " ", capture.split("\n")[0], "\27[0m"

{.compile: "packcc.c" .}
