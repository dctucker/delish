# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deligrammar
import deliengine
import deliast
import strutils
import std/tables
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

var symbol_stack = Stack[string]()

var stack_table = initTable[string, Stack[DeliNode]]()

proc popAny(keys: seq[string]): DeliNode =
  for key in keys:
    if stack_table[key].isEmpty():
      continue
    result = stack_table[key].pop()
    echo indent("POP ", 4*symbol_stack.len()), key, " = ", stack_table[key].len()
    return result
  return deliNone()

proc popOption(key: string): DeliNode =
  if not stack_table[key].isEmpty():
    result = stack_table[key].pop()
    echo indent("POP ", 4*symbol_stack.len()), key, " = ", stack_table[key].len()
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
    echo indent("capture: ", 4*symbol_stack.len()), matchStr.replace("\n","\\n")

proc pushNode(symbol: string, node: DeliNode) =
  var stack = addr stack_table[symbol]
  stack[].push(node)
  echo indent("PUSH ", 4*symbol_stack.len()), symbol, " = ", stack[].len()

proc popNode(symbol, matchStr: string) =
  var stack = addr stack_table[symbol]

  case symbol
  of "StrLiteral":   pushNode(symbol, DeliNode(kind: dkString,   strVal: matchStr))
  of "Identifier":   pushNode(symbol, DeliNode(kind: dkIdentifier,   id: matchStr))
  of "Boolean":      pushNode(symbol, DeliNode(kind: dkBoolean, boolVal: matchStr == "true"))
  of "Integer":      pushNode(symbol, DeliNode(kind: dkInteger,  intVal: parseInt(matchStr)))
  of "ArgShortName",
     "ArgLongName":  pushNode(symbol, DeliNode(kind: dkArg,     argName: matchStr))

  of "ArgDefault":
    let opt = popAny(@["Boolean","StrLiteral","Integer","StrBlock"])
    case opt.kind
    of dkBoolean:    pushNode(symbol, DeliNode(kind: dkBoolean, boolVal: opt.boolVal))
    of dkString:     pushNode(symbol, DeliNode(kind: dkString,   strVal: opt.strVal))
    of dkInteger:    pushNode(symbol, DeliNode(kind: dkInteger,  intVal: opt.intVal))
    else:            pushNode(symbol, DeliNode(kind: dkString,   strVal: ""))

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
      if p.nt.name != "Blank":
        echo indent("> ", 4*symbol_stack.len()), p.nt.name, ": ", s.substr(start).split("\n")[0]
        symbol_stack.push(p.nt.name)
    leave:
      if p.nt.name != "Blank":
        discard symbol_stack.pop()
        if length > 0:
          let matchStr = s.substr(start, start+length-1)
          echo indent("< ", 4*symbol_stack.len()), p, ": ", matchStr.replace("\\\n"," ").replace("\n","\\n")

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
engine.runProgram(script)

