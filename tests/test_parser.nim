import ./common

proc setupParser(source_path: string): Parser =
  let source = readFile(source_path)
  let source_len = source.len
  let script = makeScript(source_path, source)
  return Parser(script: script, debug: 0)

suite "parser":
  test "hello world":
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

  test "parse comparisons":
    var parser = setupParser("tests/fixtures/test_integers.deli")
    let parsed = parser.parse()

    check:
      parser.parsed_len == parser.script.source.len

    #let expected = DK( dkScript, DK( dkCode,
    #    dkStatement( dkVariableStmt( Variable:x AssignOp:= Expr:127 ( Integer:127 ) ) )
    #    dkStatement( dkVariableStmt( Variable:y AssignOp:= Expr:127 ( Integer:127 ) ) )
    #    dkStatement( dkVariableStmt( Variable:z AssignOp:= Expr:127 ( Integer:127 ) ) )
    #    dkBlock( dkConditional( dkBoolExpr( dkComparison( dkNeOp dkVarDeref:VarDeref( Variable:x ) VarDeref:VarDeref( Variable:y ) ) ) Code( Statement( ReturnStmt( Expr:1 ( Integer:1 ) ) ) ) ) )
    #    dkBlock( dkConditional( dkBoolExpr( dkComparison( dkNeOp dkVarDeref:VarDeref( Variable:y ) VarDeref:VarDeref( Variable:z ) ) ) Code( Statement( ReturnStmt( Expr:1 ( Integer:1 ) ) ) ) ) )
    #))
    let script = parsed.sons[0]
    check script.traverse(0,0).kind == dkVariableStmt
    check script.traverse(1,0).kind == dkVariableStmt
    check script.traverse(2,0).kind == dkVariableStmt
    check script.traverse(3,0).kind == dkConditional
    check script.traverse(3,0,0).kind == dkBoolExpr
    check script.traverse(3,0,0,0).kind == dkComparison
    check script.traverse(4,0).kind == dkConditional
    check script.traverse(4,0,0).kind == dkBoolExpr
    check script.traverse(4,0,0,0).kind == dkComparison
