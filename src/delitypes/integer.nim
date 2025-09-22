import std/strutils
import std/tables
import ../deliast
import common

proc dOct(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkInteger
  maxarg
  return DKStr("0" & arg.intVal.toOct(arg.intVal.sizeof).strip(chars={'0'}))

proc dHex(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkInteger
  maxarg
  return DKStr("0x" & arg.intVal.toHex.strip(chars={'0'}))

let IntegerFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "oct": dOct,
  "hex": dHex,
}.toTable
