import unittest

import ../src/deliast
import ../src/deliparser
import ../src/deliscript

proc kinds_match(node: DeliNode, check: DeliNode): bool =
  result = true
  if node.kind != check.kind:
    echo "kinds to not match: ", node.kind, " != ", check.kind
    return false
  for i in check.sons.low .. check.sons.high:
    let son1 = node.sons[i]
    let son2 = check.sons[i]
    if not kinds_match(son1, son2):
      return false

test "parser":
  let source_path = "tests/fixtures/test_parser.deli"
  let source = readFile(source_path)
  let source_len = source.len
  let script = makeScript(source_path, source)
  var parser = Parser(script: script, debug: 0)

  let parsed = parser.parse()
  check:
    parser.parsed_len == source_len

  #echo parser.script.getLine(1)
  check:
    parser.script.getLine(1) == "out \"hello world\", 4\n"

  let check = DK( dkScript, DK( dkCode, DK( dkStatement,
    DK( dkStreamStmt,
      DK( dkStream, DK( dkStreamOut ) ),
      DK( dkExprList,
        DK( dkExpr, DK( dkString ) ),
        DK( dkExpr, DK( dkInteger ) )
      )
    )
  )))
  check:
    kinds_match(parsed, check)

