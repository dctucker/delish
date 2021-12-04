# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import os
import strutils
#import sequtils

if paramCount() < 1:
  echo "usage: delish script.deli"
  quit 2

let source = readFile(paramStr(1))

import pegs

#
##type Args = Table[string, string]
#
#let grammar = peg"""
#  comment        <- '#' @ \n
#  statement      <- arg_stmt
#  arg_stmt       <- "arg" \s arg_names \s* "=" \s* arg_default
#  arg_names      <- ( arg_short_name, [ white space, arg_long_name ] ) | arg_long_name ;
#  arg_short_name <- "-" \w
#  arg_long_name  <- "-" ("-" \w+)*
#  arg_default    <- strliteral / integer / constant
#  constant       <- "true" / "false" / "in" / "out" / "err"
#  strliteral     <- '"' \w* '"' / "'" \w* "'"
#  integer        <- \d+
#"""
#
#let parser = grammar.eventParser:
#  pkNonTerminal:
#    enter:
#      pStack.add p.nt.name
#    leave:
#      pStack.setLen pStack.high
#
#let r = parser.match(source)

#var line_out = ""
#let lines = map( splitLines(source), proc(line: string): string =
#  if line.endsWith("\\"):
#    line_out &= line[0 .. ^2]
#    return
#  else:
#    line_out &= line
#
#  var ret = line_out
#  line_out = ""
#  return ret
#)




### AST representation

type
  DeliKind = enum
    dkNone,
    dkVariable,
    dkString,
    dkInteger,
    dkBoolean,
    dkArgStmt
  DeliNode = ref object
    case kind: DeliKind
    of dkNone: none: bool
    of dkString: strVal: string
    of dkInteger: intVal: int
    of dkBoolean: boolVal: bool
    of dkVariable: name: string
    of dkArgStmt:
      short_name, long_name: string
      default_value: DeliNode

proc parseTokens(str: string): DeliNode =
  let tokens = splitWhitespace(str)
  for token in tokens:
    if token.startsWith("$"):
      return DeliNode(kind: dkVariable, name: token[1 .. ^1])
    if token.startsWith('"') or token.startsWith("'"):
      return DeliNode(kind: dkString, strVal: token[1 .. ^2])
    if token =~ peg"'true' / 'false'":
      return DeliNode(kind: dkBoolean, boolVal: token == "true")
    if token =~ peg"\d+":
      return DeliNode(kind: dkInteger, intVal: token.parseInt)
    return DeliNode(kind: dkNone)

var statement = ""
let lines = splitLines(source)
for line in lines:
  if line.startsWith("#"):
    continue
  if line.endsWith("\\"):
    statement &= line[0 .. ^2]
    continue
  statement &= line

  if statement.len == 0:
    continue

  var node = DeliNode(kind: dkNone, none: true)
  let tokens = splitWhitespace(statement)
  for i, token in tokens:
    if node.kind == dkNone:
      case token
      of "arg":
        node = DeliNode(kind: dkArgStmt)
        continue

    case node.kind
    of dkArgStmt:
      if token.startsWith("--"):
        node.long_name = token
      elif token.startsWith("-"):
        node.short_name = token
      elif token == "=":
        node.default_value = parseTokens(join(tokens[i+1 .. ^1], " "))
        break
    else:
      continue

  stdout.writeLine("Statement ", node[])
  statement = ""



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
