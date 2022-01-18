import deliast

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
  case o1.kind
  of dkInteger:
    return o1.intVal == o2.intVal
  of dkPath, dkString, dkStrLiteral, dkStrBlock:
    return o1.strVal == o2.strVal
  of dkNone:
    return o2.kind == dkNone
  else:
    todo "== ", o1.kind, " ", o2.kind


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
    of dkString:
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

  return deliNone()

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
