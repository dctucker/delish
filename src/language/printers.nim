proc printSons*(node: DeliNode): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= " " & $son
      if son.sons.len() > 0:
        result &= "("
        result &= printSons(son)
        result &= ") "

proc printSons*(node: DeliNode, level: int): string =
  result = ""
  if node.sons.len() > 0:
    for son in node.sons:
      result &= indent($son, 4*level)
      result &= printSons(son, level+1)

proc printObject(node: DeliNode): string =
  for k,v in node.value.table.pairs():
    result &= k & ": " & $v
    result &= "; "

proc printValue*(v: DeliNode): string =
  if( v.sons.len() > 0 ):
    result &= "("
    result &= printSons(v)
    result &= ")"
  elif v.kind == dkObject:
    result &= "["
    result &= printObject(v)
    result &= "]"
  #elif v.kind in dkTypeKinds:
  else:
    result &= $v
