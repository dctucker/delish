import npeg, strutils, tables

type Dict = Table[string, int]

let parser = peg("Script"):
  Script        <- Code * !1
  Code          <- +( *Bl * VLine ) * *Bl:
    echo "Code"
  Bl            <- "\\\n" | '\9' | ' '
  VLine         <- '\n' | Comment | Block | ( Statement * *Comment * '\n' )
  Comment       <- '#' * *( 1 - {'\n'}) * '\n'
  Expr          <- VarDeref | Arg: #| Object | Array | StrBlock | StrLiteral | Integer | Boolean | Path | JsonBlock | Stream
    echo "Expr"
  Block         <- Conditional | WhileLoop | ForLoop | Subshell | Function:
    echo "Block"
  Conditional   <- "if"    * +Bl * Expr     * +Bl * "{" * *Space * *Code * *Space * "}" * *Space:
    echo "Conditional"
  WhileLoop     <- "while" * +Bl * Expr     * +Bl * "{" * *Space * *Code * *Space * "}" * *Space:
    echo "WhileLoop"
  ForLoop       <- "for"   * +Bl * Variable * +Bl * "in" * +Bl * Expr * +Bl * "{" * *Space * *Code * *Space * "}" * *Space:
    echo "ForLoop"
  Subshell      <- "sub"   * +Bl            * +Bl * "{" * *Space * *Code * *Space * "}" * *Space:
    echo "Subshell"
  Function      <- Identifier * *Bl * "=" * *Bl * "{" * *Space * *Code * *Space * "}" * *Space:
    echo "Function"
  Statement     <- "func" #AssignStmt / LocalStmt / OpenStmt / CloseStmt / ArgStmt / EnvStmt / IncludeStmt / StreamStmt / RunStmt / FunctionStmt
  Identifier    <- >+Word:
    echo "Identifier: ", $1
  Integer       <- >+Digit
  Arg           <- >"--yes":
    echo "Arg: ", $1
  StrLiteral    <- ('"' * >*( 1 - {'"'} )) | ("'" * >*(1 - {'\''}))
  VarDeref      <- Variable * *( '.' * ( StrLiteral | Integer | Variable | Identifier ) )
  Variable      <- '$' * >+Word: echo "Variable: ", $1
  Word          <- {'A'..'Z','a'..'z','0'..'9','-','_'}

#let parser = peg("pairs", d: Dict):
#  pairs  <- pair * *(',' * pair) * !1
#  word   <- +Alpha
#  number <- +Digit
#  pair   <- >word * '=' * >number:
#    d[$1] = parseInt($2)
#
#var words: Table[string, int]
#doAssert parser.match("one=1,two=2,three=3,four=4", words).ok
#echo words

let r = parser.match("""
#hello world
if --yes {
  func
}
""")
echo r
