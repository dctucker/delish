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

proc parseCapture(start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    captures.push(matchStr)
    echo indent("\27[33mcapture: \27[1;4m", 4*symbol_stack.len()), matchStr.replace("\n","\\n"), "\27[0m"

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

proc newNode(symbol: string): DeliNode =
  result = case symbol
  of "StrLiteral",
     "StrBlock":   DeliNode(kind: dkString,    strVal: popCapture())
  of "Path":       DeliNode(kind: dkPath,      strVal: popCapture())
  of "Identifier": DeliNode(kind: dkIdentifier,    id: popCapture())
  of "Variable":   DeliNode(kind: dkVariable, varName: popCapture())
  of "Invocation": DeliNode(kind: dkInvocation,   cmd: popCapture())
  of "Boolean":    DeliNode(kind: dkBoolean,  boolVal: popCapture() == "true")
  of "Stream":     DeliNode(kind: dkStream,    intVal: parseStreamInt(popCapture()))
  of "Integer":    DeliNode(kind: dkInteger,   intVal: parseInt(popCapture()))
  of "Arg":        DeliNode(kind: dkArg)
  of "ArgShort":   DeliNode(kind: dkArgShort, argName: popCapture())
  of "ArgLong":    DeliNode(kind: dkArgLong,  argName: popCapture())
  else:
    let k = parseEnum[DeliKind]("dk" & symbol)
    DeliNode(kind: k)


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
        echo indent("> ", 4*symbol_stack.len()), p.nt.name, ": \27[34m", s.substr(start).split("\n")[0], "\27[0m"
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

          let node = newNode(symbol)

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
engine.runProgram(script)

