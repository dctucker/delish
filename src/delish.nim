# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import strutils
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
  arg_names      <- ( arg_short_name \s+ / arg_long_name \s+ )+
  arg_short_name <- "-" \w
  arg_long_name  <- "-" ("-" \w+)+
  arg_default    <- { strliteral / integer / constant }
  strliteral     <- '"' \w+ '"' / "'" \w+ "'"
  integer        <- \d+
  constant       <- "true" / "false" / "in" / "out" / "err"
"""

#if source =~ grammar:
#  echo matches



let parser = grammar.eventParser:
  pkNonTerminal:
    enter:
      echo "enter nt ", p
    leave:
      if length > 0:
        let matchStr = s.substr(start, start+length-1)
        echo "leave nt ", p
        #" at ", matchStr
        case p.nt.name
        of "arg_stmt":
          echo matchStr

let r = parser(source)
echo r




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
