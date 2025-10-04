import std/[
  strutils,
  tables,
]
import ./common

proc dOct(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkInteger
  maxarg
  return DKStr("0" & arg.intVal.toOct(arg.intVal.sizeof).strip(chars={'0'}, trailing=false))

proc dHex(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkInteger
  maxarg
  return DKStr("0x" & arg.intVal.toHex.strip(chars={'0'}, trailing=false))

let IntegerFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "oct": dOct,
  "hex": dHex,
}.toTable
