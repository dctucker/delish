### Engine ###

proc runtimeError(engine: Engine, msg: varargs[string,`$`]) =
  #engine.readhead.next = nil
  engine.setHeads(engine.tail)
  var message = ""
  for m in msg:
    message &= m
  raise RuntimeError(msg: message)

proc setupError(engine: Engine, msg: varargs[string,`$`]) =
  #engine.readhead.next = nil
  engine.setHeads(engine.tail)
  var message = ""
  for m in msg:
    message &= m
  raise SetupError(msg: "(setup) " & message)

proc setHeads(engine: Engine, list: DeliListNode) {.inline.} =
  engine.readhead = list
  engine.writehead = engine.readhead

proc printStatements*(engine: Engine, all: bool = false) =
  var head: DeliListNode
  var unread = false
  if all:
    head = engine.statements.head
  else:
    head = engine.readhead
  var indicator = ""
  while head != nil:
    if head == engine.readhead:
      unread = true

    let stmt = head.value
    let line = if stmt.line < 0:
      "." & $(-stmt.line)
    else:
      ":" & $stmt.line
    indicator = if head == engine.tail:
      if unread: "▼" else: "▽"
    else:
      if unread: "▶" else: "▷"

    if head == engine.writehead:
      indicator = "\27[4m" & indicator & "\27[24m"
    stderr.write " \27[36m", line, indicator, "\27[48;5;235m", stmt.repr[0..^2], "\27[0m"
    head = head.next
    stderr.write "\n"
  stderr.write "\27[36mEND⏚\27[0m\n"

proc clearStatements*(engine: Engine) =
  engine.statements = @[deliNone()].toSinglyLinkedList

proc insertStmt*(engine: Engine, node: DeliNode) =
  if node.script == nil:
    if engine.current.kind != dkNone:
      node.script = engine.current.script
  if node.kind in @[ dkStatement, dkBlock, dkCode ]:
    for s in node.sons:
      engine.insertStmt(s)
    return

  if engine.writehead == engine.tail:
    var listnode = newSinglyLinkedNode[DeliNode](engine.tail.value)
    engine.writehead.value = node
    engine.writehead.next = listnode
    engine.writehead = listnode
    engine.tail = engine.writehead

  else:
    #     w                w
    #  A  B  Z       A  B  C  Z
    var sw = engine.writehead.next
    let listnode = newSinglyLinkedNode[DeliNode](node)
    engine.writehead.next = listnode
    listnode.next = sw
    engine.writehead = listnode

proc insertStmt(engine: Engine, nodes: seq[DeliNode]) =
  for node in nodes:
    engine.insertStmt(node)

proc removeStmt(engine: Engine): DeliNode =
  var stmt = engine.readhead.value
  engine.statements.remove(engine.readhead)
  return stmt

proc initScript(engine: Engine, script: DeliNode) =
  var endline = 0
  if engine.tail != nil:
    endline = engine.tail.value.line

  for s in script.sons:
    endline = max(endline, s.line)
    for s2 in s.sons:
      endline = max(endline, s2.line)
      engine.insertStmt(s2)
  engine.insertStmt(DKInner(0, deliNone()))
  engine.tail = engine.writehead
  engine.setHeads(engine.statements.head.next)

  if script.script != nil:
    endline = max(endline, script.script.line_count + 1)
  engine.tail.value.line = endline
  engine.assignVariable(".return", DeliNode( kind: dkJump, list_node: engine.tail ))

  debug 3:
    echo engine.statements

proc sourceFile*(engine: Engine): string =
  result = ""
  if engine.current.script != nil:
    result = engine.current.script.filename

proc sourceLine*(engine: Engine): string =
  if engine.current.script != nil:
    return engine.current.script.getLine( engine.current.line )

proc lineInfo*(engine: Engine): string =
  var filename: string
  var sline: string

  let line = engine.current.line
  sline = getOneliner(engine.current)
  if engine.current.script != nil:
    filename = engine.current.script.filename
    if line != 0:
      sline = engine.current.script.getLine(abs(line))

  let delim = if line > 0:
    ":"
  else:
    "."
  let linenum = "\27[1;30m" & filename & delim & $abs(line)
  let source = " \27[0;34;4m" & sline
  let parsed = "\27[1;24m " & repr(engine.current)
  return linenum & source & parsed & "\27[0m"

proc doInclude(engine: Engine, included: DeliNode) =
  let filename = engine.evaluate(included).toString()
  let script = loadScript(filename)
  let parser = Parser(script: script, debug: engine.debug)
  let parsed = parser.parse()
  for s in parsed.sons:
    engine.insertStmt(s.sons)

proc doIncludes(engine: Engine, node: DeliNode) =
  case node.kind:
  of dkScript, dkCode, dkStatement:
    for n in node.sons:
      engine.doIncludes(n)
  of dkIncludeStmt:
    engine.doStmt(node)
  else:
    discard

proc initIncludes(engine: Engine, script: DeliNode) =
  engine.doIncludes(script)

proc debugNext(engine: Engine) =
  debug 3:
    stdout.write("\27[30;1m  next = ")
    var head = engine.readhead.next
    while head != nil:
      let l = head.value.line
      var line = ":" & $l
      if l < 0:
        line = "." & $(-l)
      stdout.write("\27[4m", line, "\27[24m ")
      head = head.next
    stdout.write("\27[0m\n")

proc nextLen*(engine: Engine): int =
  result = 0
  var head = engine.readhead.next
  while head != nil:
    result += 1
    head = head.next

proc setup*(engine: Engine, script: DeliNode) =
  engine.initArguments(script)
  engine.initIncludes(script)
  engine.initFunctions(script)
  engine.initScript(script)

proc teardown(engine: Engine) =
  for k,v in engine.fds.pairs():
    v.close()
