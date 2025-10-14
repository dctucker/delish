import ./common
import strutils
from std/os import getEnv

proc asString*(src: DeliValue): DeliValue

proc argToString(node: DeliValue): string =
  # TODO include value
  result = case node.kind
  of dkArg:        node.argName
  of dkArgShort:   node.argName
  of dkArgLong:    node.argName
  else: "?"

proc arrayToString(node: DeliValue): string =
  for son in node.sons:
    result &= son.asString.strVal & " "
  result = result[0..^2]

proc objectToString(node: DeliValue): string =
  result = "["
  for key, value in node.table:
    result &= key & ": \"" & value.asString.strVal & "\", "
  result = result[0..^3]
  result &= "]"

proc asString*(src: DeliValue): DeliValue =
  result = DKStr("")
  result.strVal = case src.kind
  of dkStrLiteral,
     dkStrBlock,
     dkString:     src.strVal
  of dkIdentifier: src.id
  of dkVariable:   src.varName
  of dkArg,
     dkArgLong,
     dkArgShort:   src.argToString
  of dkPath:       src.strVal
  of dkInteger:    $(src.intVal)
  of dkBoolean:    $(src.boolVal)
  of dkArray:      src.arrayToString
  of dkStream:     $(src.intVal)
  of dkDecimal:    $(src.decVal)
  of dkObject,
     dkRan:        src.objectToString
  of dkDateTime:   $(src.dtVal)
  else: $src.kind & "?"


proc dSplit(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextarg dkString
  let str = arg
  nextopt DKStr(" ")
  let sep = arg

  result = DK(dkArray)
  for s in str.strVal.split(sep.strVal):
    result.addSon DKStr(s)

proc gSplit(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextarg dkString
  let str = arg
  nextopt DKStr(" ")
  let sep = arg

  iterator gen(): DeliValue =
    for s in str.strVal.split(sep.strVal):
      yield DKStr(s)
  return DKIter(gen)

proc gIter(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextArg dkString
  maxarg

  let ifs = getEnv("IFS", " ")

  iterator gen(): DeliValue =
    for value in arg.strVal.split(ifs):
      yield DKStr(value)
  return DKIter(gen)

let StringFunctions* = {
  "split": dSplit,
  "iter": gIter,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkString] = {
    "split": "Returns an array of strings by splitting the string by space or the specified delimiter",
    "iter": "Generates a string after splitting the string by space",
  }.toTable
