import ./common
import ./decimal
import std/json

proc toJson(node: DeliNode): JsonNode

proc toJson(table: DeliTable): JsonNode =
  result = JsonNode(kind: JObject)
  for key,value in table:
    if value.kind == dkCallable: continue
    result.fields[key] = toJson(value)

proc toJson(sons: seq[DeliNode]): JsonNode =
  result = JsonNode(kind: JArray)
  for value in sons:
    if value.kind == dkCallable: continue
    result.elems.add toJson(value)

proc toJson(node: DeliNode): JsonNode =
  result = case node.kind
  of dkStrLiteral,
     dkStrBlock,
     dkPath,
     dkString:  JsonNode(kind: JString, str: node.strVal)
  of dkSignal,
     dkError,
     dkInt8,
     dkInt10,
     dkInt16,
     dkInteger: JsonNode(kind: JInt, num: node.intVal)
  of dkDecimal: JsonNode(kind: JFloat, fnum: node.decVal.toFloat)
  of dkBoolean: JsonNode(kind: JBool, bval: node.boolVal)
  of dkNone:    JsonNode(kind: JNull)
  of dkObject:  node.table.toJson
  of dkArray:   node.sons.toJson
  else:         JsonNode(kind: JString, str: $node)

proc dJson(nodes: varargs[DeliNode]): DeliNode =
  argvars
  shift
  let obj = arg
  maxarg

  result = DKStr($obj.toJson)

proc dKeys(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkObject
  let obj = arg

  result = DK(dkArray)
  for key in obj.table.keys:
    result.sons.add DKStr(key)

proc dLookup(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkObject
  let obj = arg
  nextarg dkIdentifier
  let id = arg.id
  return obj.table[id]

let ObjectFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "": dLookup,
  "keys": dKeys,
  "json": dJson,
}.toTable
