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
  Expr          <- VarDeref / Arg / Array / Object / StrBlock / StrLiteral / Integer / Boolean / Path / JsonBlock / Stream
  Block         <- !'$' (Conditional / WhileLoop / ForLoop / Function) / Subshell
  Conditional   <- "if"    Blank+ Expr     Blank+                         "{" \s* Code* \s* "}" \s*
  WhileLoop     <- "while" Blank+ Expr     Blank+                         "{" \s* Code* \s* "}" \s*
  ForLoop       <- "for"   Blank+ Variable Blank+ "in" Blank+ Expr Blank+ "{" \s* Code* \s* "}" \s*
  Subshell      <- "sub"   Blank+          Blank+                         "{" \s* Code* \s* "}" \s*
  Function      <- Identifier Blank* "="   Blank*                         "{" \s* Code* \s* "}" \s*
  Statement     <- OpenStmt / AssignStmt / LocalStmt / CloseStmt / ArgStmt / EnvStmt / IncludeStmt / StreamStmt / RunStmt / FunctionStmt
  AssignStmt    <- &'$' Variable Blank* ( AssignOp / AppendOp / RemoveOp )  Blank* (ArgExpr / Expr / RunStmt)
  AssignOp      <- "="
  AppendOp      <- "+="
  RemoveOp      <- "-="
  OpenStmt      <- &'$' Variable Blank* "=" Blank* "open" (Blank+ RedirOp)? Blank+ Path
  CloseStmt     <- &'$' Variable ".close"
  FunctionStmt  <- Identifier (Blank+ Expr)*
  IncludeStmt   <- "include" Blank+ StrLiteral
  RunStmt       <- (RunFlags Blank+)? "run" Blank+ Invocation ( Blank* "|" Blank* Invocation )*
  RunFlags      <- AsyncFlag / RedirFlag / (AsyncFlag RedirFlag)
  AsyncFlag     <- "async"
  RedirFlag     <- "redir" (Blank+ (Variable / Path / Stream) Blank* RedirOp Blank* (Variable / Path / Stream))+
  RedirOp       <- RedirAppendOp / RedirReadOp / RedirWriteOp / RedirDuplexOp
  RedirAppendOp <- ">>"
  RedirReadOp   <- "<"
  RedirWriteOp  <- ">"
  RedirDuplexOp <- "<>"
  Invocation    <- { \w (\w/"-")* } ( Blank+ (Expr / String) )*
  String        <- {\S+}
  EnvStmt       <- "env" Blank+ Variable (Blank* DefaultOp Blank* EnvDefault)?
  EnvDefault    <- Expr
  ArgExpr       <- Arg (Blank+ / '=') Expr?
  ArgStmt       <- "arg" ArgNames (Blank* DefaultOp Blank* ArgDefault)?
  ArgNames      <- ( Blank+ Arg )+
  Arg           <- &'-' (ArgLong / ArgShort)
  ArgShort      <- '-' { \w+ }
  ArgLong       <- "--" { (\w ('-' \w)*)+ }
  ArgDefault    <- Expr
  LocalStmt     <- "local" Blank+ Variable ( Blank* "=" Blank* Expr )?
  VarDeref      <- &'$' Variable ( [.] ( StrLiteral / Integer / Variable / Identifier ) )*
  Array         <- '[' ( \s* Expr Blank* ','? \s* )* ']'
  Object        <- '[' ( \s* Expr Blank* ':' Blank* Expr Blank* ','? \s* )+ ']'
  Integer       <- { \d+ }
  Identifier    <- !Keyword { (\w/"-")+ }
  Keyword       <- "sub" / "if" / "white" / "arg" / "in" / "out" / "err" / "include" / "true" / "false"
  StrLiteral    <- ('"' @@ '"') / ('\'' @@ '\'')
  StrBlock      <- (\"\"\") \n @@ (\"\"\")
  JsonBlock     <- "json" Blank+ StrBlock
  Path          <- { ("."* "/" \S+ ) / "." }
  Boolean       <- { "true" / "false" }
  StreamStmt    <- ( Variable "." )? Stream Blank+ ExprList
  ExprList      <- Expr ( Blank* "," Blank* Expr Blank* )*
  Stream        <- &[ioe] (StreamIn / StreamOut / StreamErr)
  StreamIn      <- "in"
  StreamOut     <- "out"
  StreamErr     <- "err"
  Variable      <- '$' { (\w / '-')+ }
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

