import strutils
import sequtils
import macros

#let file_io_funcs = """
#  unlink
#  rename
#  chdir
#  mkdir
#  chown
#  chmod
#  symlink
#"""

const grammar_source* = """
  Script        <- Code
  Code          <- ( Blank* VLine )+ Blank*
  Blank         <- ("\\" \n) / \9 / " "
  VLine         <- \n / Comment / Block / Statement Comment* \n
  Comment       <- '#' @ \n
  Expr          <- VarDeref / Arg / Object / Array / StrBlock / StrLiteral / Integer / Boolean / Path / JsonBlock / Stream
  Block         <- Conditional / Loop / Subshell / Function
  Conditional   <- "if"    Blank+ Expr Blank+ "{" \s* Code* \s* "}" \s*
  Loop          <- "while" Blank+ Expr Blank+ "{" \s* Code* \s* "}" \s*
  Subshell      <- "sub"   Blank+      Blank+ "{" \s* Code* \s* "}" \s*
  Function      <- Identifier Blank* "=" Blank* "{" \s* Code* \s* "}" \s*
  Statement     <- AssignStmt / LocalStmt / OpenStmt / CloseStmt / ArgStmt / EnvStmt / IncludeStmt / StreamStmt / RunStmt / FunctionStmt
  AssignStmt    <- Variable Blank* ( AssignOp / AppendOp )  Blank* (Expr / RunStmt)
  AssignOp      <- "="
  AppendOp      <- "+="
  OpenStmt      <- Variable ( "." Stream )? Blank* "=" Blank* "open" Blank+ Path
  CloseStmt     <- Variable ".close"
  FunctionStmt  <- Identifier (Blank+ Expr)*
  IncludeStmt   <- "include" Blank+ StrLiteral
  RunStmt       <- "run" Blank+ Invocation ( Blank* "|" Blank* Invocation )*
  Invocation    <- { \w+ } ( Blank+ Expr )*
  EnvStmt       <- "env" Blank+ Variable (Blank* "|=" Blank* EnvDefault)?
  EnvDefault    <- Expr
  ArgStmt       <- "arg" ArgNames (Blank* "|=" Blank* ArgDefault)?
  ArgNames      <- ( Blank+ Arg )+
  Arg           <- ArgLong / ArgShort
  ArgShort      <- "-" { \w+ }
  ArgLong       <- "--" { (\w ("-" \w)*)+ }
  ArgDefault    <- Expr
  LocalStmt     <- "local" Blank+ Variable ( Blank* "=" Blank* Expr )?
  VarDeref      <- Variable ( [.] ( StrLiteral / Integer / Variable / Identifier ) )*
  Object        <- "[" ( \s* Expr Blank* ":" Blank* Expr Blank* ","? \s* )+ "]"
  Array         <- "[" ( \s* Expr Blank* ","? \s* )* "]"
  Integer       <- { \d+ }
  Identifier    <- !Keyword { \w+ }
  Keyword       <- "sub" / "if" / "white" / "arg" / "in" / "out" / "err" / "include" / "true" / "false"
  StrLiteral    <- ('"' @@ '"') / ("'" @@ "'")
  StrBlock      <- (\"\"\") \n @@ (\"\"\")
  JsonBlock     <- "json" Blank+ StrBlock
  Path          <- { ("."* "/" \S+ ) / "." }
  Boolean       <- { "true" / "false" }
  StreamStmt    <- ( Variable "." )? Stream Blank+ ExprList
  ExprList      <- Expr ( Blank* "," Blank* Expr Blank* )*
  Stream        <- { "in" / "out" / "err" }
  Variable      <- "$" { \w+ }
"""

let symbol_names* = grammar_source.splitLines().map(proc(x:string):string =
  if x.contains("<-"):
    let split = x.splitWhitespace()
    if split.len() > 0:
      return split[0]
).filter(proc(x:string):bool = x.len() > 0)

macro grammarToEnum*(extra: static[seq[string]]) =
  let symbols = grammar_source.splitLines().map(proc(x:string):string =
    if x.contains("<-"):
      let split = x.splitWhitespace()
      if split.len() > 0:
        return "dk" & split[0]
  ).filter(proc(x:string):bool = x.len() > 0)
  let options = concat(symbols, extra.map(proc(x:string):string = "dk" & x))
  let stmt = "type DeliKind* = enum " & options.join(", ")
  result = parseStmt(stmt)


#proc echoItems(p: Peg) =
#  if p.len() == 0:
#    return
#  for item in p.items():
#    echo item.kind, item
#    echoItems(item)
#echoItems(grammar)
