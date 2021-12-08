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

#proc echoItems(p: Peg) =
#  if p.len() == 0:
#    return
#  for item in p.items():
#    echo item.kind, item
#    echoItems(item)
#echoItems(grammar)

var captures = Stack[string]()
var symbol_stack = Stack[string]()
#var node_stack = Stack[DeliNode]()

var stack_table = initTable[string, Stack[DeliNode]]()

#proc popAny(keys: seq[string]): DeliNode =
#  for key in keys:
#    if stack_table[key].isEmpty():
#      continue
#    result = stack_table[key].pop()
#    echo indent("POP ", 4*symbol_stack.len()), key, " = ", stack_table[key].len()
#    return result
#  return deliNone()
#
#proc popOption(key: string): DeliNode =
#  if not stack_table[key].isEmpty():
#    result = stack_table[key].pop()
#    echo indent("POP ", 4*symbol_stack.len()), key, " = ", stack_table[key].len()
#    return result
#  return deliNone()
#
#proc popExpect(key: string): DeliNode =
#  return stack_table[key].pop()


for symbol in symbol_names:
  stack_table[symbol] = Stack[DeliNode]()

#stack_table["Script"].push(DeliNode(kind: dkScript))

proc parseCapture(start, length: int, s: string) =
  if length > 0:
    let matchStr = s.substr(start, start+length-1)
    captures.push(matchStr)
    echo indent("capture: ", 4*symbol_stack.len()), matchStr.replace("\n","\\n")

proc pushNode(symbol: string, node: DeliNode) =
  var stack = addr stack_table[symbol]
  stack[].push(node)
  echo indent("PUSH ", 4*symbol_stack.len()), symbol, " = ", stack[].len()

proc popCapture(): string =
  result = captures.pop()
  echo indent("POPCAP ", 4*symbol_stack.len()), result

proc newNode(symbol: string): DeliNode =
  result = case symbol
  of "StrLiteral",
     "StrBlock":   DeliNode(kind: dkString,    strVal: popCapture())
  of "Identifier": DeliNode(kind: dkIdentifier,    id: popCapture())
  of "Variable":   DeliNode(kind: dkVariable, varName: popCapture())
  of "Invocation": DeliNode(kind: dkInvocation,   cmd: popCapture())
  of "Boolean":    DeliNode(kind: dkBoolean,  boolVal: popCapture() == "true")
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
        echo indent("> ", 4*symbol_stack.len()), p.nt.name, ": ", s.substr(start).split("\n")[0]
        symbol_stack.push(p.nt.name)
    leave:
      if p.nt.name notin ["Blank", "VLine", "Comment"]:
        let symbol = symbol_stack.pop()
        if length > 0:
          let matchStr = s.substr(start, start+length-1)
          echo indent("< ", 4*symbol_stack.len()), p, ": ", matchStr.replace("\\\n"," ").replace("\n","\\n")

          #popNode(symbol, matchStr)

          #if symbol_stack.len > 0:
          #  let parent = symbol_stack.pop()
          #symbol_stack.push(newNode(symbol))
          let parent = if symbol_stack.len() > 0:
            symbol_stack.peek()
          else: "Script"

          let node = newNode(symbol)

          for son in stack_table[symbol].toSeq():
            node.sons.add( son )
          stack_table[symbol].clear()
          pushNode(parent, node)

let r = parser(source)
if r != source.len():
  echo "\nERROR: Stopped parsing at pos ", r, "/", source.len()


proc printSons(node: DeliNode, level: int) =
  for son in node.sons:
    echo indent($(son.kind) & " " & toString(son), 4*level)
    printSons(son, level+1)

echo "\n== Stack Table =="
for k,v in stack_table:
  echo k, "="
  for node in v.toSeq():
    printSons(node, 0)
    #echo "  ", node[], " sons = ", node[].sons.len()


var engine: Engine = newEngine()
let script = stack_table["Script"].pop()
engine.runProgram(script)

