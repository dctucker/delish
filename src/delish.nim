# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deliast
import strutils
import std/tables
import stacks
#import sequtils

import pegs

import os
if paramCount() < 1:
  echo "usage: delish script.deli"
  quit 2

let source = readFile(paramStr(1))

#type Args = Table[string, string]

let grammar = peg"""
  script         <- ( \s* statement / \s* comment / \s* \n )*
  comment        <- '#' @ \n
  statement      <- arg_stmt (comment)* \n
  arg_stmt       <- "arg" \s+ arg_names \s* "=" \s+ arg_default
  arg_names      <- ( arg_name \s+ )+
  arg_name       <- ( arg_short_name / arg_long_name )
  arg_short_name <- "-" \w
  arg_long_name  <- "-" ("-" \w+)+
  arg_default    <- { strliteral / integer / constant }
  strliteral     <- '"' \w+ '"' / "'" \w+ "'"
  integer        <- \d+
  constant       <- "true" / "false" / "in" / "out" / "err"
"""

#if source =~ grammar:
#  echo matches

var stack_table = initTable[string, Stack[DeliNode]]()
stack_table["arg_short_name"] = Stack[DeliNode]()
stack_table["arg_long_name"] = Stack[DeliNode]()
stack_table["arg_default"] = Stack[DeliNode]()
stack_table["arg_stmt"] = Stack[DeliNode]()

let parser = grammar.eventParser:
  pkNonTerminal:
    leave:
      if length > 0:
        let matchStr = s.substr(start, start+length-1)
        echo "leave nt ", p, " at ", matchStr

        case p.nt.name
        of "arg_stmt":
          let short = stack_table["arg_short_name"].pop()
          let long = stack_table["arg_long_name"].pop()
          let default = stack_table["arg_default"].pop()
          stack_table["arg_stmt"].push(DeliNode(kind: dkArgStmt, short_name: short, long_name: long, default_value: default))

        of "arg_short_name":
          stack_table[p.nt.name].push(DeliNode(kind: dkArg, argName: matchStr))
        of "arg_long_name":
          stack_table[p.nt.name].push(DeliNode(kind: dkArg, argName: matchStr))
        of "arg_default":
          stack_table[p.nt.name].push(DeliNode(kind: dkArg, argName: matchStr))

let r = parser(source)
echo r

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
