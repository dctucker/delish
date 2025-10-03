proc `$`*(node: DeliNode): string
proc toString*(node: DeliNode):string

proc argFormat(node: DeliNode): string =
  var current_kind = dkNone
  result = ""
  for son in node.sons:
    case son.kind
    of dkArgLong:
      if current_kind != son.kind:
        result &= " "
      result &= "--" & son.argName
    of dkArgShort:
      if current_kind != son.kind:
        result &= "-"
      result &= son.argName
    of dkArg:
      let a = son.sons[0]
      case a.kind
      of dkArgLong:
        if current_kind != a.kind and result.len > 0:
          result &= " "
        result &= "--" & a.argName
      of dkArgShort:
        if current_kind != a.kind:
          result &= "-"
        result &= a.argName
      else:
        result &= $a
      current_kind = a.kind
      continue
    of dkString:
      result &= son.strVal
    of dkExpr:
      result &= " " & son.sons[0].toString
    else:
      result &= $son
    current_kind = son.kind

proc objFormat(node: DeliNode): string =
  result = "["
  for key,value in node.table:
    result &= key & ": " & value.toString() & "; "
  result &= "]"

proc arrayFormat(node: DeliNode): string =
  if node.sons.len == 0:
    return "[]"
  result = "[ "
  for value in node.sons:
    result &= value.toString() & ", "
  result = result[0..^3] & " ]"

proc `$`*(decimal: Decimal): string =
  return $(decimal.whole) & '.' & align($(decimal.fraction), decimal.decimals, '0')

proc timeFormat(node: DeliNode): string =
  return (
    align($node.sons[0].intVal, 2, '0') & ":" &
    align($node.sons[1].intVal, 2, '0') & ":" &
    align($node.sons[2].intVal, 2, '0') & (
      if node.sons[3].isNone(): "" else: "." & $node.sons[3].intVal
    )
  )

proc dateFormat(node: DeliNode): string =
  return node.sons.map(proc(x: DeliNode): string =
    if x.kind == dkNone:
      ""
    else:
      align($x.intVal, 2, '0')
  ).join("-")

proc toString*(node: DeliNode): string =
  let kind = node.kind
  if kind in { dkExpr, dkExprList }:
    result = ""
    for s in node.sons:
      result &= s.toString()
      result &= " "
    return result

  if kind in dkStreamKinds:
    return dkStreamKindStrings[kind]
  if kind in dkStatementKinds:
    return ""
  if kind in dkOperatorKinds:
    return dkOperatorKindStrings[kind]

  return case kind
  of dkScript:     node.script.filename
  of dkVarDeref:   "$"
  of dkIdentifier: node.id
  of dkPath,
     dkStrLiteral,
     dkStrBlock,
     dkString:     node.strVal
  of dkStream,
     dkInteger:    $(node.intVal)
  of dkDecimal:    $(node.decVal)
  of dkBoolean:    $(node.boolVal)
  of dkVariable:   $(node.varName)
  of dkDateTime:   $(node.dtVal)
  of dkTime:       node.timeFormat
  of dkDate:       node.dateFormat
  of dkPair:       ""
  of dkObject,
     dkRan:        objFormat(node)
  of dkArray:      arrayFormat(node)
  of dkArgDefault:
    if node.sons.len > 0:
      $(node.sons[0])
    else:
      ""
  of dkInvocation: node.cmd
  of dkArg:
    argFormat(node)
  of dkArgShort:
    "-" & node.argName
  of dkArgLong:
    "--" & node.argName
  of dkArgExpr:
    argFormat(node)
  of dkCallable:
    if node.function != nil:
      "Function=" & node.function.repr
    else:
      ""
  of dkJump:
    if node.list_node != nil:
      $node.list_node.value.line
    else:
      "Jump"
  of dkInner, dkNone, dkType:
    ""
  else:
    if kind.ord <= dkKeyword.ord or kind.ord >= dkLazy.ord:
      ""
    else:
      todo "toString " & kind.name
      ""

proc `$`*(node: DeliNode): string =
  let value = node.toString()
  if value == "":
    return node.kind.name
  else:
    return node.kind.name & ":" & value

proc todo*(msg: varargs[string, `$`]) =
  errlog.write("\27[0;33mTODO: ", msg.join(""), "\27[0m\n")

proc lineage*(node: DeliNode): string =
  var n = node
  #result = n.parent.kind.name
  while n.parent.kind != dkNone:
    result = n.parent.kind.name & "/" & result
    n = n.parent

proc repr*(node: DeliNode): string =
  result = ""
  if node.parents.len == 0:
    result = "⌱"

  if node.kind == dkExpr:
    result &= node.kind.name
  else:
    result &= $node

  if node.sons.len > 0:
    result &= "( "
    for n in node.sons:
      result &= repr(n)
    result &= ")"
  result &= " "

proc treeRepr*(node: DeliNode, indent: int = 0): string =
  result = ""
  if node.parents.len == 0:
    result = "⌱"

  if node.kind == dkExpr:
    result &= node.kind.name
  else:
    result &= $node

  var nl: string
  var ni: int

  case node.kind
  of dkScript,
     dkExpr,
     dkStatement:
    ni = indent
    nl = ""
  else:
    ni = indent + 1
    nl = "\n" & repeat(" ", ni)

  if node.sons.len > 0:
    result &= "( " & nl
    for son in node.sons:
      result &= treeRepr(son, ni)
    if ni == indent:
      result &= ")"
    else:
      result &= nl & repeat(" ", indent) & ")"
  result &= " "


proc getOneliner*(node: DeliNode): string =
  case node.kind
  of dkNone:
    return "nop"
  of dkVariableStmt:
    return "$" & node.sons[0].varName & " " & node.sons[1].toString() & " " & node.sons[2].toString()
  of dkCloseStmt:
    return "close $" & node.sons[0].varName
  of dkLocalStmt:
    result = "local $" & node.sons[0].varName
    if node.sons.len > 1:
      result &= " = " & node.sons[1].toString()
  of dkPush: return "push"
  of dkPop:  return "pop"
  of dkJump:
    let line = if node.list_node == nil:
      "end"
    else:
      $(node.list_node.value.line)
    return "jump :" & line
  of dkInner:
    result = "{ "
    for son in node.sons:
      result &= son.getOneliner()
      result &= " ; "
    result = result[0..^4] & " }"
  of dkConditional:
    return "if " & $(node.sons[0].repr) & $(node.sons[1].repr)
  of dkReturnStmt, dkBreakStmt, dkContinueStmt:
    let k = $(node.kind)
    return k.substr(2, k.len - 5).toLowerAscii
  else:
    return $(node.kind) & "?"
