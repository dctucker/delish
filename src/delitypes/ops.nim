import ../deliast
import std/tables

proc `<=`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal <= o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal <= o2.strVal
  else:
    todo "<= ", o1.kind, " ", o2.kind

proc `<`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal < o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal < o2.strVal
  else:
    todo "< ", o1.kind, " ", o2.kind

proc `>=`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal >= o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal >= o2.strVal
  else:
    todo ">= ", o1.kind, " ", o2.kind

proc `>`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal > o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal > o2.strVal
  else:
    todo "> ", o1.kind, " ", o2.kind

proc `!=`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal != o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal != o2.strVal
  of dkNone:
    return o2.kind != dkNone
  else:
    todo "!= ", o1.kind, " ", o2.kind

proc `==`*(o1, o2: DeliNode): bool =
  if o1.kind == dkNone or o2.kind == dkNone:
    return o1.kind == o2.kind

  # TODO deal with non-equivalent kinds
  assert o1.kind == o2.kind
  case o1.kind
  of dkInteger:
    return o1.intVal == o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal == o2.strVal
  of dkBoolean:
    return o1.boolVal == o2.boolVal
  of dkNone:
    return o2.kind == dkNone
  of dkArg, dkArgShort, dkArgLong:
    # should this attempt to dereference?
    return o1.kind == o2.kind and o1.argName == o2.argName
  of dkArray:
    if o1.sons.len != o2.sons.len:
      return false
    for i in 0 .. o1.sons.len - 1:
      if o1.sons[i] != o2.sons[i]:
        return false
    return true
  of dkObject:
    if o1.table.len != o2.table.len:
      return false
    for key in o1.table.keys:
      if o1.table[key] != o2.table[key]:
        return false
    return true
  of dkRegex:
    return o1.pattern == o2.pattern
  of dkStream:
    return o1.intVal == o2.intVal
  of dkIdentifier:
    # should this attempt to dereference?
    return o1.id == o2.id
  of dkVariable:
    return o1.varName == o2.varName
  else:
    todo "== ", o1.kind, " ", o2.kind

proc `==`*(o: DeliNode, i: int): bool =
  if o.kind == dkInteger:
    return o.intVal == i
  return false

proc `==`*(o: DeliNode, s: string): bool =
  if o.kind == dkString:
    return o.strVal == s
  return false

proc `==`*(o: DeliNode, b: bool): bool =
  if o.kind == dkBoolean:
    return o.boolVal == b
  return false


proc `not`*(a: DeliNode): DeliNode =
  case a.kind:
  of dkBoolean:
    return DeliNode(kind: dkBoolean, boolVal: not a.boolVal)
  else:
    todo "not ", a.kind

proc `+`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: a.intVal + b.intval)
    of dkString, dkPath:
      return DeliNode(kind: dkString, strVal: a.strVal & b.strVal)
    of dkArray:
      result = DeliNode(kind: dkArray)
      for n in a.sons:
        result.sons.add(n)
      for n in b.sons:
        result.sons.add(n)
        return result
    of dkArg:
      return DK(dkArgExpr, a, b)
    else:
      todo "add ", a.kind, " + ", b.kind
      return deliNone()

  case a.kind
  of dkArray:
    a.sons.add(b)
    return a
  of dkArgExpr:
    a.sons.add(b)
    return a
  else:
    todo "add ", a.kind, " + ", b.kind
    return a

proc `-`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: a.intVal - b.intval)
    else:
      todo "sub ", a.kind, " - ", b.kind
      return deliNone()
  return deliNone()

proc `*`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: a.intVal * b.intval)
    else:
      todo "mul ", a.kind, " * ", b.kind
      return deliNone()
  return deliNone()

proc `/`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger:
      return DeliNode(kind: dkInteger, intVal: (a.intVal / b.intval).int)
    else:
      todo "div ", a.kind, " / ", b.kind
      return deliNone()
  return deliNone()

proc `and`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkBoolean:
      return DKBool( a.boolVal and b.boolVal )
    else:
      todo "con ", a.kind, " and ", b.kind

proc `or`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkBoolean:
      return DKBool( a.boolVal or b.boolVal )
    else:
      todo "dis ", a.kind, " or ", b.kind
