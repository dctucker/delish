import system/io
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

const grammar_source_0 = staticRead("delish.peg").replace('\n','\0')

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

macro grammarToCEnum*(extra: static[seq[string]]) =
  let symbols = getGrammar().splitLines().map(proc(x:string):string =
    if x.contains("<-"):
      let split = x.splitWhitespace()
      if split.len() > 0:
        return "dk" & split[0]
  ).filter(proc(x:string):bool = x.len() > 0)
  let options = concat(symbols, extra.map(proc(x:string):string = "dk" & x))
  let stmt = "enum DeliKind {\n\t" & options.join(",\n\t") & "\n};\n";
  "src/delikind.h".writeFile(stmt)
