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
  Script        <- ( Blank* VLine )+ Blank*
  Blank         <- ("\\" \n) / \9 / " "
  VLine         <- \n / Comment / BlockBegin / BlockEnd / Statement Comment* \n
  Comment       <- '#' @ \n
  Conditional   <- "if" Blank+ Expr
  Loop          <- "while" Blank+ Expr
  Subshell      <- "sub" Blank+
  BlockHead     <- Conditional / Loop / Subshell
  BlockBegin    <- BlockHead Blank+ "{"
  BlockEnd      <- "}"
  Statement     <- AssignStmt / ArgStmt / IncludeStmt / StreamStmt / RunStmt / FunctionStmt
  AssignStmt    <- Variable Blank* AssignOp Blank* (Expr / RunStmt)
  AssignOp      <- Assign / AppendOp
  Assign        <- "="
  AppendOp      <- "+="
  FunctionStmt  <- Identifier
  IncludeStmt   <- "include" Blank+ StrLiteral
  RunStmt       <- "run" Blank+ Invocation ( Blank* "|" Blank* Invocation )* \n
  Invocation    <- { \w+ } ( Blank+ Expr )+
  ArgStmt       <- "arg" Blank+ ArgNames Blank* "=" Blank+ ArgDefault
  ArgNames      <- ( Arg Blank+ )+
  Arg           <- ArgLong / ArgShort
  ArgShort      <- "-" { \w+ }
  ArgLong       <- { "-" ("-" \w+)+ }
  ArgDefault    <- Expr
  Expr          <- ArrayLiteral / StrBlock / StrLiteral / Integer / Boolean / VarDeref / Variable / Arg / Path / EmptyArray / JsonBlock
  EmptyArray    <- "[" Blank* "]"
  ArrayLiteral  <- "[" Blank* ExprList Blank* "]"
  Integer       <- { \d+ }
  Identifier    <- !Keyword { \w+ }
  Keyword       <- "sub" / "if" / "white" / "arg" / "in" / "out" / "err" / "include" / "true" / "false"
  StrLiteral    <- ('"' @@ '"') / ("'" @@ "'")
  StrBlock      <- (\"\"\") \n @@ (\"\"\")
  JsonBlock     <- "json" Blank+ StrBlock
  VarDeref      <- Variable ( DotOp ( StrLiteral / Integer / Variable / Identifier ) )+
  DotOp         <- "."
  Path          <- "." / ("."? "/") @@ \s*
  Boolean       <- { "true" } / { "false" }
  Variable      <- "$" { \w+ }
  StreamStmt    <- Stream Blank+ ExprList
  ExprList      <- Expr ( Blank* "," Blank* Expr Blank* )*
  Stream        <- "in" / "out" / "err"
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

