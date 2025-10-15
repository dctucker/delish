import std/[strutils,tables]
import ../language/ast
import ../errors

const buildWithUsage* {.booldefine.}: bool = false
when buildWithUsage:
  var typeFuncUsage*: Table[DeliKind, Table[string, string]]

template argerr*(msg: varargs[string, `$`]) =
  raise newException(ValueError, msg.join(""))

template express*() =
  if arg.kind == dkExpr:
    arg = arg.sons[0]
  if arg.kind == dkArg:
    arg = arg.sons[0]

template shift*() =
  if arg_i >= nodes.len:
    argerr "missing argument; args: ", nodes
  arg = nodes[arg_i]
  arg_i += 1

template expect*(k) =
  express
  if arg.kind != k:
    raise newException(ValueError, "expected " & k.name & ", not " & arg.kind.name)

template nextarg*(k: static[DeliKind]) =
  shift
  expect k

template nextarg*(kinds: static[set[DeliKind]]) =
  shift
  express
  if arg.kind notin kinds:
    argerr "expected one of ", kinds, ", not ", arg.kind.name

template nextopt*(default: DeliValue) =
  if arg_i >= nodes.len:
    arg = default
  else:
    arg = nodes[arg_i]
    express
    arg_i += 1
    if arg.kind != default.kind:
      if default.kind in dkIntegerKinds and arg.kind notin dkIntegerKinds:
        raise newException(ValueError, "expected " & default.kind.name & ", not " & arg.kind.name)

template maxarg*() =
  if nodes.len > arg_i:
    raise newException(ValueError, "too many arguments: " & $nodes)

template argvars*() =
  var arg_i {.inject.}: int = 0
  var arg {.inject.}: DeliValue

template noargs*() =
  if nodes.len > 0:
    raise newException(ValueError, "too many arguments: " & $nodes)

proc dNop*(nodes: varargs[DeliValue]): DeliValue =
  return deliNone()

template pluralMaybe*(node, formula: untyped): untyped =
  var node: DeliValue
  if nodes.len == 1:
    if nodes[0].kind == dkArray:
      result = DK(dkArray)
      for node in nodes[0].sons:
        result.addSon formula
    else:
      node = nodes[0]
      return formula
  else:
    result = DK(dkArray)
    for node in nodes:
      result.addSon formula

export ast
export tables
export errors
