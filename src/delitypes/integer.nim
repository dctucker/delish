import std/[
  strutils,
]
import ./common

proc dOct(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkIntegerKinds
  maxarg
  return DeliNode(kind: dkInt8, intVal: arg.intVal)

proc dDec(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkIntegerKinds
  maxarg
  return DeliNode(kind: dkInt10, intVal: arg.intVal)

proc dHex(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkIntegerKinds
  maxarg
  return DeliNode(kind: dkInt16, intVal: arg.intVal)

let IntegerFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "oct": dOct,
  "dec": dDec,
  "hex": dHex,
}.toTable
