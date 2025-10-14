import std/json
import ./common
import ./decimal

proc toJson(node: DeliValue): JsonNode

proc toJson(table: DeliTable): JsonNode =
  result = JsonNode(kind: JObject)
  for key,value in table:
    if value.kind == dkCallable: continue
    result.fields[key] = toJson(value)

proc toJson(sons: seq[DeliValue]): JsonNode =
  result = JsonNode(kind: JArray)
  for value in sons:
    if value.kind == dkCallable: continue
    result.elems.add toJson(value)

proc toJson(node: DeliValue): JsonNode =
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

proc dJson(nodes: varargs[DeliValue]): DeliValue =
  argvars
  shift
  let obj = arg
  maxarg

  result = DKStr($obj.toJson)

proc dKeys(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextarg dkObject
  let obj = arg

  result = DK(dkArray)
  for key, value in obj.table:
    if value.kind notin {dkCallable, dkIterable}:
      result.addSon DKStr(key)

proc gIter(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextArg dkObject
  maxarg

  iterator gen(): DeliValue =
    for key, value in arg.table:
      if value.kind notin {dkCallable, dkIterable}:
        yield DKStr(key)
  return DKIter(gen)

proc dLookup(nodes: varargs[DeliValue]): DeliValue =
  argvars
  nextarg dkObject
  let obj = arg
  nextarg dkIdentifier
  let id = arg.id
  return obj.table[id]

let ObjectFunctions*: Table[string, proc(nodes: varargs[DeliValue]): DeliValue {.nimcall.} ] = {
  #"": dLookup,
  "keys": dKeys,
  "json": dJson,
  "iter": gIter,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkObject] = {
    "keys": "Returns an array of strings representing the object's keys",
    "json": "Returns a JSON string representing the object",
    "iter": "Generates a string for each of the object's keys",
  }.toTable
