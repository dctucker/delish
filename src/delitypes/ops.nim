import std/tables
import ./common
import ./decimal

proc `<=`*(o1, o2: DeliNode): bool =
  case o1.kind
  of dkInteger:
    return o1.intVal <= o2.intVal
  #of dkDecimal:
  #  return o1.decVal <= o2.decVal
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
  of dkDecimal:
    return o1.decVal != o2.decVal
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
  of dkDecimal:
    return o1.decVal == o2.decVal
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
    of dkInteger: return DKInt(a.intVal + b.intval)
    of dkDecimal: return DKDec(a.decVal + b.decVal)
    of dkString,
      dkPath:     return DKStr(a.strVal & b.strVal)
    of dkArg:     return DK(dkArgExpr, a, b)
    of dkArray:
      result = DeliNode(kind: dkArray)
      for n in a.sons: result.sons.add(n)
      for n in b.sons: result.sons.add(n)
      return result
    else:
      todo "add ", a.kind, " + ", b.kind
      return deliNone()

  case a.kind
  of dkArray:
    result = DeliNode(kind: dkArray)
    for n in a.sons: result.sons.add(n)
    result.sons.add(b)
  of dkArgExpr:
    result = DeliNode(kind: dkArgExpr)
    for n in a.sons: result.sons.add(n)
    result.sons.add(b)
  else:
    todo "add ", a.kind, " + ", b.kind
    return a

proc `-`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(a.intVal - b.intval)
    of dkDecimal: return DKDec(a.decVal - b.decVal)
    else: discard
  todo "sub ", a.kind, " - ", b.kind
  return deliNone()

proc `*`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(a.intVal * b.intVal)
    of dkDecimal: return DKDec(a.decVal * b.decVal)
    else: discard
  todo "mul ", a.kind, " * ", b.kind
  return deliNone()

proc `/`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(a.intVal div b.intVal)
    of dkDecimal: return DKDec(a.decVal / b.decVal)
    else: discard
  todo "div ", a.kind, " / ", b.kind
  return deliNone()

proc `mod`*(a, b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(a.intVal mod b.intVal)
    of dkDecimal: return DKDec(a.decVal mod b.decVal)
    else: discard
  todo "mod ", a.kind, " % ", b.kind
  return deliNone()

proc `xor`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt( a.intVal xor b.intVal )
    of dkBoolean: return DKBool( a.boolVal xor b.boolVal )
    else: discard
  todo "excl ", a.kind, " xor ", b.kind

proc xnor*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(  not ( a.intVal xor b.intVal ) )
    of dkBoolean: return DKBool( not ( a.boolVal xor b.boolVal ) )
    else: discard
  todo "conn ", a.kind, " nxor ", b.kind

proc `and`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt( a.intVal and b.intVal )
    of dkBoolean: return DKBool( a.boolVal and b.boolVal )
    else: discard
  todo "con ", a.kind, " and ", b.kind

proc nand*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(  not ( a.intVal  and b.intVal  ) )
    of dkBoolean: return DKBool( not ( a.boolVal and b.boolVal ) )
    else: discard
  todo "ncon ", a.kind, " nand ", b.kind

proc `or`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt( a.intVal or b.intVal )
    of dkBoolean: return DKBool( a.boolVal or b.boolVal )
    else: discard
  todo "dis ", a.kind, " or ", b.kind

proc nor*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt(  not ( a.intVal  or b.intVal  ) )
    of dkBoolean: return DKBool( not ( a.boolVal or b.boolVal ) )
    else: discard
  todo "ndis ", a.kind, " nor ", b.kind

proc `shl`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt( a.intVal shl b.intVal )
    else: discard
  todo "shl ", a.kind, " by ", b.kind

proc `shr`*(a,b: DeliNode): DeliNode =
  if a.kind == b.kind:
    case a.kind
    of dkInteger: return DKInt( a.intVal shr b.intVal )
    else: discard
  todo "shr ", a.kind, " by ", b.kind
