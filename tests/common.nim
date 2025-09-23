import ../src/deliast

proc traverse*(tree: DeliNode, args: varargs[int]): DeliNode =
  result = tree
  for arg in args:
    result = result.sons[arg]

proc kinds_match*(node: DeliNode, check: DeliNode): bool =
  result = true
  if node.kind != check.kind:
    echo "kinds to not match: ", node.kind, " != ", check.kind
    return false
  for i in check.sons.low .. check.sons.high:
    let son1 = node.sons[i]
    let son2 = check.sons[i]
    if not kinds_match(son1, son2):
      return false

