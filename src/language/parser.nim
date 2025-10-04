import std/[
  os,
  strutils,
  tables,
]
import ./ast
import ../[
  stacks,
  errors,
  deliscript,
]
import ../delitypes/parse

const deepDebug {.booldefine.}: bool = false

type
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
    entry_point:  DeliNode
    script*:      DeliScript
    symbol_stack: Stack[DeliKind]
    brackets*:    Stack[char]
    nodes:        seq[DeliNode]
    errors*:      seq[ErrorMsg]
    metrics:      OrderedTable[DeliKind,Metric]
    max_depth:    int

proc `$`*(e: ErrorMsg): string =
  result = e.msg & " (" & $e.pos & ")"

proc packcc_main(input: cstring, len: cint, parser: Parser): cint {.importc.}

proc initParser(parser: Parser) =
  parser.symbol_stack.clear
  parser.brackets.clear
  parser.errors = @[]
  parser.metrics.clear

template debug(level: int, code: untyped) =
  if parser.debug >= level:
    code

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

proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent($son, 4*level)
    printSons(son, level+1)


## Parser

proc parse*(parser: Parser): DeliNode =
  parser.initParser()

  var cstr = parser.script.source.cstring
  parser.nodes = @[deliNone()]
  discard packcc_main(cstr, parser.script.source.len.cint, parser)
  if parser.brackets.len > 0:
    let b = parser.brackets.peekUnsafe()
    parser.errors.add(ErrorMsg(pos: parser.script.source.len, msg: "expected closing `" & b & "`"))
  parser.entry_point = parser.nodes[^1]
  parser.entry_point.script = parser.script
  debug 2:
    echo "entry point = ", parser.entry_point
  return parser.entry_point

proc quickParse*(parser: Parser, str: string): DeliNode =
  parser.script = makeScript("", str)
  result = parser.parse()
  if parser.errors.len > 0:
    var msg = ""
    for e in parser.errors:
      msg &= $e & "\n"
    raise newException(ParserError, msg.strip)

proc quickParse*(str: string): DeliNode =
  var parser = Parser()
  return parser.quickParse(str)

## PackCC integration stuff

type PackEvent = enum
  peEvaluate, peMatch, peNoMatch

proc pccError(parser: Parser, cur: csize_t): void {.exportc.} =
  when deepDebug:
    debug 2:
      stderr.write "\n"
  if parser.errors.len == 0:
    parser.errors.add ErrorMsg(pos: cur.int, msg: "syntax error")

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
  of dkInt16,
     dkInt8,
     dkInteger:    node.intVal  = parseInteger(capture)
  of dkYear, dkMonth, dkDay,
     dkHour, dkMinute, dkSecond,
     dkInt10:      node.intVal = parseInt10(capture)
  of dkNanoSecond: node.intVal = parseNanoSecond(capture)
  of dkDecimal:    node.decVal  = parseDecimal(capture)
  of dkArgShort:   node.argName = capture
  of dkArgLong:    node.argName = capture
  else:
    todo "capture failed for ", $(node.kind), " '", capture, "'"

proc addNode(parser: Parser, node: DeliNode) =
  parser.nodes.add node

proc bracket(parser: Parser, pos: int, c: char, d: int8) {.exportc.} =
  #echo "\n", pos, $c, $d, "\n"
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
  let son1 = parser.getNode(s1) ; son1.parent = node
  node.sons.add(son1)
  parser.addNode node

proc createNode2(parser: Parser, kind: DeliKind, s1, s2: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode2 ", $kind, " ", $s1, " ", $s2, "\n"
  var node = DeliNode(kind: kind, sons: @[])
  let son1 = parser.getNode(s1) ; son1.parent = node
  let son2 = parser.getNode(s2) ; son2.parent = node
  node.sons.add(son1)
  node.sons.add(son2)
  parser.addNode node

proc createNode3(parser: Parser, kind: DeliKind, s1, s2, s3: cint): cint {.exportc.} =
  result = parser.nodes.len.cint
  debug 3:
    stderr.write $result, " createNode3 ", $kind, " ", $s1, " ", $s2, " ", $s3, "\n"
  var node = DeliNode(kind: kind, sons: @[])
  let son1 = parser.getNode(s1) ; son1.parent = node
  let son2 = parser.getNode(s2) ; son2.parent = node
  let son3 = parser.getNode(s3) ; son3.parent = node
  node.sons.add(son1)
  node.sons.add(son2)
  node.sons.add(son3)
  parser.addNode node

proc nodeAppend(parser: Parser, p, s: cint): cint {.exportc.} =
  let son = parser.getNode(s)
  let parent = parser.getNode(p)
  son.parent = parent
  debug 3:
    stderr.write $p, " nodeAppend ", $son.kind, " ", $s, "\n"
  parent.sons.add(son)
  result = p

proc setLine(parser: Parser, dk: cint, l: cint): cint {.exportc.} =
  debug 3:
    stderr.write $dk, " setLine ", $l, "\n"
  var node = parser.getNode(dk)
  node.line = parser.script.line_number(l.int)
  if node.kind == dkScript:
    node.script = parser.script
  parser.nodes[dk] = node

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
  case rule
  of dkC.ord, dkW.ord, dkU.ord, dkS.ord, dkVLine.ord, dkComment.ord: return
  else: discard

  parser.parsed_len = max(parser.parsed_len, pos.int)
  parser.max_depth = max(parser.max_depth, level)

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
