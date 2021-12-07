# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deliengine
import deliast
import strutils
import std/tables
import stacks
import sequtils

import pegs

import os
if paramCount() < 1:
  echo "usage: delish script.deli"
  quit 2

let source = readFile(paramStr(1))

let grammar_source = """
  Script        <- ( \s* \n
                   / \s* Comment
                   / \s* Statement \n
                   )+
                   \s*
  Comment       <- '#' @ \n
  Conditional   <- "if" \s+ Expr \s+ Block \s*
  Block         <- "{"
                     ( \s* \n
                     / \s* Comment
                     / \s* Statement \n
                     )*
                     \s*
                   "}"

  Statement     <- (Conditional / ArgStmt / IncludeStmt / StreamStmt / FunctionStmt) (Comment)*
  FunctionStmt  <- Identifier
  IncludeStmt   <- "include" \s+ StrLiteral
  ArgStmt       <- "arg" \s+ ArgNames \s* "=" \s+ ArgDefault
  ArgNames      <- ( Arg \s+ )+
  Arg           <- ArgLongName / ArgShortName
  ArgShortName  <- "-" { \w }
  ArgLongName   <- { "-" ("-" \w+)+ }
  ArgDefault    <- Expr
  Expr          <- StrLiteral / Integer / Boolean / Variable / Arg
  Integer       <- { \d+ }
  Identifier    <- { \w+ }
  StrLiteral    <- ('"' @@ '"') / ("'" @@ "'")
  Boolean       <- { "true" } / { "false" }
  Variable      <- "$" { \w+ }
  StreamStmt    <- Stream ExprList
  ExprList      <- Expr ( \s* "," \s* Expr \s* )*
  Stream        <- "in" / "out" / "err"
"""

let symbol_names = grammar_source.splitLines().map(proc(x:string):string =
  let split = x.splitWhitespace()
  if split.len() > 0:
    return split[0]
).filter(proc(x:string):bool = x.len() > 0)

let grammar = peg(grammar_source)

#proc echoItems(p: Peg) =
#  if p.len() == 0:
#    return
#  for item in p.items():
#    echo item.kind, item
#    echoItems(item)
#echoItems(grammar)

var symbol_stack = Stack[string]()

var stack_table = initTable[string, Stack[DeliNode]]()
proc popOption(key: string): DeliNode =
  if not stack_table[key].isEmpty():
    result = stack_table[key].pop()
    echo indent("pop ", 4*symbol_stack.len()), key, " = ", stack_table[key].len()
    return result
  return deliNone()

proc popExpect(key: string): DeliNode =
  return stack_table[key].pop()


for symbol in symbol_names:
  stack_table[symbol] = Stack[DeliNode]()

stack_table["Script"].push(DeliNode(kind: dkClause))

proc parseCapture(start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    echo indent("capture: ", 4*symbol_stack.len()), matchStr

proc pushNewNode(symbol: string) =
  #var stack = addr stack_table[symbol]
  case symbol
  of "Statement":
    discard

proc pushNode(symbol: string, node: DeliNode) =
  var stack = addr stack_table[symbol]
  stack[].push(node)
  echo indent("push ", 4*symbol_stack.len()), symbol, " = ", stack[].len()

proc popNode(symbol, matchStr: string) =
  var stack = addr stack_table[symbol]
  case symbol

  of "StrLiteral":
    pushNode(symbol, DeliNode(kind: dkString, strVal: matchStr))
  of "Identifier":
    pushNode(symbol, DeliNode(kind: dkIdentifier, id: matchStr))
  of "Boolean":
    pushNode(symbol, DeliNode(kind: dkBoolean, boolVal: matchStr == "true"))
  of "Integer":
    pushNode(symbol, DeliNode(kind: dkInteger, intVal: parseInt(matchStr)))

  of "ArgShortName", "ArgLongName":
    pushNode(symbol, DeliNode(kind: dkArg, argName: matchStr))
  of "ArgDefault":
    let b = popOption("Boolean")
    let c = popOption("StrLiteral")
    let d = popOption("Integer")
    if b.kind != dkNone:
      pushNode(symbol, DeliNode(kind: dkBoolean, boolVal: b.boolVal))
    elif c.kind != dkNone:
      pushNode(symbol, DeliNode(kind: dkString, strVal: c.strVal))
    elif d.kind != dkNone:
      pushNode(symbol, DeliNode(kind: dkInteger, intVal: parseInt(matchStr)))
    else:
      pushNode(symbol, DeliNode(kind: dkString, strVal: ""))

  of "ArgStmt":
    let short = popOption("ArgShortName")
    let long  = popOption("ArgLongName")
    let default = popExpect("ArgDefault")
    #let k = parseEnum[DeliKind]("dk" & symbol)
    stack[].push(DeliNode(kind: dkArgStmt, short_name: short, long_name: long, default_value: default))

  of "IncludeStmt":
    let literal = popExpect("StrLiteral")
    pushNode(symbol, DeliNode(kind: dkIncludeStmt, includeVal: literal))

  of "FunctionStmt":
    let id = popExpect("Identifier")
    pushNode(symbol, DeliNode(kind: dkFunctionStmt, funcName: id))

  of "Statement":
    for popme in ["ArgStmt", "IncludeStmt", "FunctionStmt"]:
      if not stack_table[popme].isEmpty():
        var clause = popExpect("Script")
        clause.addStatement(popExpect(popme))
        stack_table["Script"].push(clause)

let parser = grammar.eventParser:
  pkCapture:
    leave:
      parseCapture(start, length, s)
  pkCapturedSearch:
    leave:
      parseCapture(start, length-1, s)
  pkNonTerminal:
    enter:
      pushNewNode(p.nt.name)

      echo indent("enter ", 4*symbol_stack.len()), p.nt.name
      symbol_stack.push(p.nt.name)
    leave:
      discard symbol_stack.pop()
      if length > 0:
        let matchStr = s.substr(start, start+length-1)
        echo indent("leave ", 4*symbol_stack.len()), p, ": ", matchStr

        let symbol = p.nt.name
        popNode(symbol, matchStr)

let r = parser(source)
if r != source.len():
  echo "\nERROR: Stopped parsing at pos ", r, "/", source.len()

echo "\n== Stack Table =="
for k,v in stack_table:
  echo k, "="
  for node in v.toSeq():
    echo "  ", node[]

var engine: Engine = newEngine()
let script = stack_table["Script"].pop()
for s in script.statements:
  echo s[]
  case s.kind
  of dkArgStmt:
    var sn = ""
    var ln = ""
    var dv = ""
    if s.short_name.kind == dkArg:
      sn = s.short_name.argName
    if s.long_name.kind == dkArg:
      ln = s.long_name.argName
    dv = case s.default_value.kind
    of dkString:
      s.default_value.strVal
    of dkInteger:
      $(s.default_value.intVal)
    of dkBoolean:
      $(s.default_value.boolVal)
    else:
      $s.default_value.kind

    engine.addArgument(sn, ln, dv)
  of dkIncludeStmt:
    echo s.includeVal.strVal
    #engine.addInclude(s.includeVal)
  of dkFunctionStmt:
    echo s.funcName.id
  else:
    echo $(s.kind)



### do stuff with environment
#
#import std/os, sequtils
#when isMainModule:
#  stdout.write "$ "
#  var cmdline = readLine(stdin)
#
#  if cmdline == "envars":
#    for k,v in envPairs():
#      stdout.write(k, " ")
#    stdout.write("\n")
#
#  if cmdline == "glob":
#    let dir = toSeq(walkDir(".", relative=true))
#    for f in dir:
#      echo f
#
#
