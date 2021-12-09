# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deligrammar
import deliengine
import deliast
import strutils
import std/tables
import std/deques
import stacks
import pegs

import os
if paramCount() < 1:
  echo "usage: delish script.deli"
  quit 2

let source = readFile(paramStr(1))

var captures     = Stack[string]()
var symbol_stack = Stack[string]()
var stack_table  = initTable[string, Stack[DeliNode]]()

for symbol in symbol_names:
  stack_table[symbol] = Stack[DeliNode]()

iterator line_offsets(src: string): int =
  var start = 0
  let length = src.len()
  while start < length:
    yield start
    start = src.find("\n", start) + 1

var line_numbers: seq[int] = @[0]
for offset in line_offsets(source):
  line_numbers.add(offset)
echo line_numbers

proc line_number(pos: int): int =
  for line, offset in line_numbers:
    if offset > pos:
      return line - 1

proc parseCapture(start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    captures.push(matchStr)
    echo indent("\27[1;33mcapture: \27[4m", 4*symbol_stack.len()), matchStr.replace("\n","\\n"), "\27[0m"

proc pushNode(symbol: string, node: DeliNode) =
  var stack = addr stack_table[symbol]
  stack[].push(node)
  echo indent("PUSH ", 4*symbol_stack.len()), symbol, " = ", stack[].len()

proc popCapture(): string =
  result = captures.pop()
  echo indent("POPCAP ", 4*symbol_stack.len()), result

proc parseStreamInt(str: string): int =
  case str
  of "in":  return 0
  of "out": return 1
  of "err": return 2

proc newNode(symbol: string, line: int): DeliNode =
  result = case symbol
  of "StrLiteral",
     "StrBlock":   DeliNode(line: line, kind: dkString,    strVal: popCapture())
  of "Path":       DeliNode(line: line, kind: dkPath,      strVal: popCapture())
  of "Identifier": DeliNode(line: line, kind: dkIdentifier,    id: popCapture())
  of "Variable":   DeliNode(line: line, kind: dkVariable, varName: popCapture())
  of "Invocation": DeliNode(line: line, kind: dkInvocation,   cmd: popCapture())
  of "Boolean":    DeliNode(line: line, kind: dkBoolean,  boolVal: popCapture() == "true")
  of "Stream":     DeliNode(line: line, kind: dkStream,    intVal: parseStreamInt(popCapture()))
  of "Integer":    DeliNode(line: line, kind: dkInteger,   intVal: parseInt(popCapture()))
  of "Arg":        DeliNode(line: line, kind: dkArg)
  of "ArgShort":   DeliNode(line: line, kind: dkArgShort, argName: popCapture())
  of "ArgLong":    DeliNode(line: line, kind: dkArgLong,  argName: popCapture())
  else:
    let k = parseEnum[DeliKind]("dk" & symbol)
    DeliNode(kind: k, line: line)

let grammar* = peg(grammar_source)
let parser = grammar.eventParser:
  pkCapture:
    leave:
      parseCapture(start, length, s)
  pkCapturedSearch:
    leave:
      case symbol_stack.peek()
      of "StrBlock":
        parseCapture(start, length-3, s)
      else:
        parseCapture(start, length-1, s)
  pkNonTerminal:
    enter:
      if p.nt.name notin ["Blank", "VLine", "Comment"]:
        echo "\27[1;30m", indent("> ", 4*symbol_stack.len()), p.nt.name, ": \27[0;34m", s.substr(start).split("\n")[0], "\27[0m"
        symbol_stack.push(p.nt.name)
    leave:
      if p.nt.name notin ["Blank", "VLine", "Comment"]:
        let symbol = symbol_stack.pop()
        if length > 0:
          let matchStr = s.substr(start, start+length-1)
          echo indent("\27[1m< ", 4*symbol_stack.len()), p, "\27[0m: \27[34m", matchStr.replace("\\\n"," ").replace("\n","\\n"), "\27[0m"

          let parent = if symbol_stack.len() > 0:
            symbol_stack.peek()
          else: "Script"

          let line = line_number(start)
          #echo start, " :",  line
          let node = newNode(symbol, line)

          for son in stack_table[symbol].toSeq():
            node.sons.add( son )
          stack_table[symbol].clear()
          pushNode(parent, node)




let parsed_len = parser(source)


proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent(toString(son), 4*level)
    printSons(son, level+1)

echo "\n== Stack Table =="
for k,v in stack_table:
  echo k, "="
  for node in v.toSeq():
    printSons(node, 0)
    #echo "  ", node[], " sons = ", node[].sons.len()

if parsed_len != source.len():
  echo "\nERROR: Stopped parsing at pos ", parsed_len, "/", source.len()
  quit 1

var engine: Engine = newEngine()
let script = DeliNode(kind: dkScript, sons: stack_table["Script"].toSeq())
#engine.runProgram(script)

for line in engine.tick(script):
  let start = line_numbers[line]
  let endl  = line_numbers[line+1]
  stdout.write( "\27[1;30m:", line, " \27[0;34;4m", source.substr(start, endl-2), "\27[1;24m" )

