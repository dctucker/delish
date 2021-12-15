import strutils
import sequtils
import macros
#import pegs

#let file_io_funcs = """
#  unlink
#  rename
#  chdir
#  mkdir
#  chown
#  chmod
#  symlink
#"""

#let VLine = term("\n")
#let Blank = sequence( term("\\"), term("\n") ) / term("\9") / term(" ")
#let Code = sequence( +sequence( *Blank, VLine ), *Blank )
#echo Code.repr

const grammar_source_0 = static"""
  Script        <- Code
  Code          <- ( Blank* VLine )+ Blank*
  Blank         <- ("\\" \n) / \9 / " "
  VLine         <- \n / Comment / Block / Statement Comment* \n
  Comment       <- '#' @ \n
  Block         <- !'$' (Conditional / WhileLoop / ForLoop / Function) / Subshell
  Statement     <- OpenStmt / AssignStmt / LocalStmt / CloseStmt / ArgStmt / EnvStmt / IncludeStmt / StreamStmt / RunStmt / FunctionStmt
  Conditional   <- "if"       Blank+ Expr     Blank+                         "{" \s* Code* \s* "}" \s*
  WhileLoop     <- "while"    Blank+ Expr     Blank+                         "{" \s* Code* \s* "}" \s*
  ForLoop       <- "for"      Blank+ Variable Blank+ "in" Blank+ Expr Blank+ "{" \s* Code* \s* "}" \s*
  Function      <- Identifier Blank* "="      Blank*                         "{" \s* Code* \s* "}" \s*
  Subshell      <- "sub"      Blank+          Blank+                         "{" \s* Code* \s* "}" \s*
  OpenStmt      <- &'$' Variable Blank* "=" Blank* "open" (Blank+ RedirOp)? Blank+ Path
  AssignStmt    <- &'$' Variable Blank* ( AssignOp / AppendOp / RemoveOp )  Blank* (ArgExpr / Expr / RunStmt)
  LocalStmt     <- "local" Blank+ Variable ( Blank* "=" Blank* Expr )?
  CloseStmt     <- &'$' Variable ".close"
  ArgStmt       <- "arg" ArgNames (Blank* DefaultOp Blank* ArgDefault)?
  EnvStmt       <- "env" Blank+ Variable (Blank* DefaultOp Blank* EnvDefault)?
  IncludeStmt   <- "include" Blank+ StrLiteral
  StreamStmt    <- ( Variable "." )? Stream Blank+ ExprList
  RunStmt       <- ( (AsyncFlag / RedirFlag / (AsyncFlag RedirFlag) ) Blank+)? "run" Blank+ Invocation ( Blank* "|" Blank* Invocation )*
  FunctionStmt  <- Identifier (Blank+ Expr)*
  ArgDefault    <- Expr
  EnvDefault    <- Expr
  ExprList      <- Expr ( Blank* "," Blank* Expr Blank* )*
  Invocation    <- { \w (\w/"-")* } ( Blank+ (Expr / String) )*
  ArgExpr       <- Arg (Blank+ / '=') Expr?
  Expr          <- VarDeref / Arg / Array / Object / StrBlock / StrLiteral / Integer / Boolean / Path / JsonBlock / Stream
  VarDeref      <- &'$' Variable ( [.] ( StrLiteral / Integer / Variable / Identifier ) )*
  RedirFlag     <- "redir" (Blank+ (Variable / Path / Stream) Blank* RedirOp Blank* (Variable / Path / Stream))+
  AsyncFlag     <- "async"
  ArgNames      <- ( Blank+ Arg )+
  Arg           <- &'-' (ArgLong / ArgShort)
  ArgShort      <- '-' { \w+ }
  ArgLong       <- "--" { (\w ('-' \w)*)+ }
  Array         <- '[' ( \s* Expr Blank* ','? \s* )* ']'
  Object        <- '[' ( \s* Expr Blank* ':' Blank* Expr Blank* ','? \s* )+ ']'
  Identifier    <- !Keyword { (\w/"-")+ }
  JsonBlock     <- "json" Blank+ StrBlock
  StrBlock      <- (\"\"\") \n @@ (\"\"\")
  StrLiteral    <- ('"' @@ '"') / ('\'' @@ '\'')
  String        <- { \S+ }
  Integer       <- { \d+ }
  Path          <- { ("."* "/" \S+ ) / "." }
  Variable      <- '$' { (\w / '-')+ }
  Keyword       <- "sub" / "if" / "white" / "arg" / "in" / "out" / "err" / "include" / "true" / "false"
  Boolean       <- { "true" / "false" }
  Stream        <- &[ioe] (StreamIn / StreamOut / StreamErr)
  StreamIn      <- "in"
  StreamOut     <- "out"
  StreamErr     <- "err"
  AssignOp      <- "="
  AppendOp      <- "+="
  RemoveOp      <- "-="
  RedirOp       <- RedirAppendOp / RedirReadOp / RedirWriteOp / RedirDuplexOp
  RedirAppendOp <- ">>"
  RedirReadOp   <- "<"
  RedirWriteOp  <- ">"
  RedirDuplexOp <- "<>"
  DefaultOp     <- "|="
""".replace('\n','\0')

proc getGrammar*():string = grammar_source_0.replace('\0','\n')

macro grammarToEnum*(extra: static[seq[string]]) =
  let symbols = getGrammar().splitLines().map(proc(x:string):string =
    if x.contains("<-"):
      let split = x.splitWhitespace()
      if split.len() > 0:
        return "dk" & split[0]
  ).filter(proc(x:string):bool = x.len() > 0)
  let options = concat(symbols, extra.map(proc(x:string):string = "dk" & x))
  let stmt = "type DeliKind* = enum " & options.join(", ")
  result = parseStmt(stmt)

