import system
import std/[
  strutils,
  sequtils,
  macros,
]

const deepDebug {.booldefine.}: bool = false

#let file_io_funcs = """
#  unlink
#  rename
#  chdir
#  mkdir
#  chown
#  chmod
#  symlink
#"""

const grammar_source_0 = staticRead("delish.packcc").replace('\n','\0')

proc getGrammar():string = grammar_source_0.replace('\0','\n')
const grammar_lines = getGrammar().splitLines()

proc getSymbols(): seq[string] {.compileTime.} =
  result = grammar_lines.map(proc(x:string):string =
    if x.contains("<-"):
      let split = x.splitWhitespace()
      if split.len() > 0:
        if split[0].len > 1:
          return "dk" & split[0]
  ).filter(proc(x:string):bool = x.len() > 0)

proc simplifyBody(body: string): string {.compileTime.} =
  result = body
  while ( result.contains("~{") or result.contains(" {") ) and result.contains("}"):
    var pos1, pos2: int
    pos1 = result.find(" ~{ ")
    if pos1 > 0:
      pos2 = result.find("}", start=pos1)
      result = result[0..pos1-1] & result[pos2+1..^1]
    pos1 = result.find(" { ")
    if pos1 > 0:
      pos2 = result.find("}", start=pos1)
      result = result[0..pos1-1] & result[pos2+1..^1]

  result = result.splitWhitespace().join(" ").strip

proc getRule(name: string): string {.compileTime.} =
  var found = false
  var body = ""
  for x in grammar_lines:
    if x.startsWith(name & " "):
      found = true
      result = x.split("<-")[1].simplifyBody
      continue

    if found and not x.startsWith(" "):
      break

    result &= " " & x.simplifyBody

proc getSubKinds(kind: string): seq[string] {.compileTime.} =
  return getRule(kind).replace("(","").replace(")","").split("/").map(proc(x:string): string =
    result = x
    if result.contains(":"):
      result = result.split(":")[1]
    result = "dk" & result.replace("\"","").replace("\"","").strip
  )

macro grammarSubKinds*(kind: static[string]) =
  let kinds = getSubKinds(kind)
  let stmt = "const dk" & kind & "Kinds = { " & kinds.join(", ") & " }"
  when deepDebug: echo stmt
  result = parseStmt(stmt)

proc getKindStrings(kind: string): seq[string] {.compileTime.} =
  return getRule(kind).replace("(","").replace(")","").split("/").map(proc(s:string):string = s.strip)

macro grammarKindStrings*(kind: static[string]) =
  let kinds = getKindStrings(kind)
  let stmt = "const dk" & kind & "Strings = [" & kinds.join(", ") & "]"
  when deepDebug: echo stmt
  result = parseStmt(stmt)

macro grammarSubKindStrings*(kind: static[string]) =
  let kinds = getSubKinds(kind)
  var stmt = "const dk" & kind & "KindStrings = {\n"
  for k in kinds:
    let str = getKindStrings(k[2..^1]).join("")
    stmt &= "  " & k & ": " & str & ",\n"
  stmt &= "}.toTable"
  when deepDebug: echo stmt
  result = parseStmt(stmt)

proc getOperatorKinds(): seq[string] {.compileTime.} =
  return getSymbols().filter(proc(x: string): bool =
    return x.endsWith("Op")
  )

macro grammarOpKinds*() =
  let ops = getOperatorKinds()
  let stmt = "const dkOperatorKinds = { " & ops.join(", ") & " }"
  when deepDebug: echo stmt
  result = parseStmt(stmt)

macro grammarOpKindStrings*() =
  let kinds = getOperatorKinds()
  var stmt = "const dkOperatorKindStrings = {\n"
  for k in kinds:
    var str: string
    for x in grammar_lines:
      if x.startsWith(k[2..^1] & " "):
         str = x.split("<-")[1].simplifyBody
         break

    stmt &= "  " & k & ": " & str & ",\n"
  stmt &= "}.toTable"
  when deepDebug: echo stmt
  result = parseStmt(stmt)

macro grammarToEnum*(extra: static[seq[string]]) =
  let symbols = getSymbols()
  let options = concat(symbols, extra.map(proc(x:string):string = "dk" & x))
  let stmt = "type DeliKind* = enum " & options.join(", ")
  result = parseStmt(stmt)

macro grammarToCEnum*(extra: static[seq[string]]) =
  let symbols = getSymbols()
  let options = concat(symbols, extra.map(proc(x:string):string = "dk" & x))
  let stmt = "enum DeliKind {\n\t" & options.join(",\n\t") & "\n};\n";
  "src/language/kind.h".writeFile(stmt)

# TODO produce lists representing literals
# Keyword
# Type
# Operator
#   RedirOp
#   Comparator
#   MathOp (MulOp, DivOp, ModOp, AddOp, SubOp)
