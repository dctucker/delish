# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

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

#type Args = Table[string, string]

let grammar_source = """
  script         <- ( \s* statement \n / \s* comment / \s* \n )+
  comment        <- '#' @ \n
  statement      <- (arg_stmt / include_stmt / function_stmt) (comment)*
  function_stmt  <- (\w+)
  include_stmt   <- "include" \s+ strliteral
  arg_stmt       <- "arg" \s+ arg_names \s* "=" \s+ arg_default
  arg_names      <- ( arg_name \s+ )+
  arg_name       <- ( arg_short_name / arg_long_name )
  arg_short_name <- "-" \w
  arg_long_name  <- "-" ("-" \w+)+
  arg_default    <- strliteral / integer / constant
  strliteral     <- '"' @ '"' / "'" @ "'"
  integer        <- \d+
  constant       <- "true" / "false" / "in" / "out" / "err"
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


var stack_table = initTable[string, Stack[DeliNode]]()
proc popOption(key: string): DeliNode =
  if not stack_table[key].isEmpty():
    return stack_table[key].pop()
  return deliNone()


for symbol in symbol_names:
  stack_table[symbol] = Stack[DeliNode]()

stack_table["script"].push(DeliNode(kind: dkClause))

let parser = grammar.eventParser:
  pkNonTerminal:
    leave:
      if length > 0:
        let matchStr = s.substr(start, start+length-1)
        echo "leave nt ", p, " at ", matchStr

        let symbol = p.nt.name
        var stack = addr stack_table[symbol]
        case symbol
        of "arg_stmt":
          var short = popOption("arg_short_name")
          var long  = popOption("arg_long_name")
          let default = stack_table["arg_default"].pop()
          stack[].push(DeliNode(kind: dkArgStmt, short_name: short, long_name: long, default_value: default))

        of "arg_short_name":
          stack[].push(DeliNode(kind: dkArg, argName: matchStr))
        of "arg_long_name":
          stack[].push(DeliNode(kind: dkArg, argName: matchStr))
        of "arg_default":
          stack[].push(DeliNode(kind: dkArg, argName: matchStr))
        of "strliteral":
          stack[].push(DeliNode(kind: dkString, strVal: matchStr))
        of "include_stmt":
          let literal = stack_table["strliteral"].pop()
          stack[].push(DeliNode(kind: dkIncludeStmt, includeVal: literal))
        of "statement":
          for popme in ["arg_stmt", "include_stmt", "function_stmt"]:
            if not stack_table[popme].isEmpty():
              var clause = stack_table["script"].pop()
              clause.addStatement(stack_table[popme].pop())
              stack_table["script"].push(clause)

let r = parser(source)
if r != source.len():
  echo "\nERROR: Stopped parsing at pos ", r, "/", source.len()

echo "\n== Stack Table =="
for k,v in stack_table:
  echo k, "="
  for node in v.toSeq():
    echo node[]





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
