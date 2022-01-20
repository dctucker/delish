import unittest

import ../src/deliast
import ../src/deliparser

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
  var parser = Parser(source: source, debug: 0)

  let parsed = parser.parse()
  doAssert parsed == source_len

  echo parser.getLine(1)
  doAssert parser.getLine(1) == "out \"hello world\", 4\n"

  let node = parser.getScript()
  let check = DK( dkScript, DK( dkCode, DK( dkStatement,
    DK( dkStreamStmt,
      DK( dkStream, DK( dkStreamOut ) ),
      DK( dkExprList,
        DK( dkExpr, DK( dkString ) ),
        DK( dkExpr, DK( dkInteger ) )
      )
    )
  )))
  doAssert kinds_match(node, check)

