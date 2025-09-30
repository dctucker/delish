import ./common

suite "flow control":
  test "if/elif/else block":
    let source_path = "tests/fixtures/test_ifelse.deli"
    let source = readFile(source_path)
    let script = makeScript(source_path, source)
    var parser = Parser(script: script, debug: 0)
    var parsed = parser.parse()
    var node: DeliNode

    var engine = newEngine(parsed, 0)
    discard engine.doNext()
    check engine.getVariable("k").boolVal == true

    check engine.sourceLine() == "if $k {"
    discard engine.doNext()
    check engine.sourceLine() == "  $k = \"yes\""
    discard engine.doNext()
    check engine.sourceLine() == "return"


    node = parsed.traverse(0,0,0,2)
    node.sons[0] = deliFalse()

    engine = newEngine(parsed, 0)
    discard engine.doNext()
    check engine.getVariable("k").boolVal == false

    check engine.sourceLine() == "if $k {"
    discard engine.doNext()
    check engine.sourceLine() == "} elif not $k {"
    discard engine.doNext()
    check engine.sourceLine() == "  $k = \"not\""
    discard engine.doNext()
    check engine.sourceLine() == "return"

    node = parsed.traverse(0,0,0,2)
    node.sons[0] = DKStr("something else") # TODO this will change soon

    engine = newEngine(parsed, 0)
    discard engine.doNext()
    check engine.getVariable("k").strVal == "something else"

    check engine.sourceLine() == "if $k {"
    discard engine.doNext()
    check engine.sourceLine() == "} elif not $k {"
    discard engine.doNext()
    check engine.sourceLine() == "} else {"
    discard engine.doNext()
    check engine.sourceLine() == "  $k = \"no\""
    discard engine.doNext()
    check engine.sourceLine() == "return"

