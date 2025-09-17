import deliast

proc toIdentifier*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkIdentifier:
    DeliNode(kind: dkIdentifier, id: src.id)
  of dkString:
    DeliNode(kind: dkIdentifier, id: src.strVal)
  of dkVariable:
    DeliNode(kind: dkIdentifier, id: src.varName)
  of dkArg, dkArgShort, dkArgLong:
    # TODO check this
    DeliNode(kind: dkIdentifier, id: src.argName)
  else:
    raise newException(ValueError, "incompatible type: Identifier(" & $src.kind & ")")

proc toVariable*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkVariable:
    DeliNode(kind: dkVariable, varName: src.varName)
  of dkString,
     dkIdentifier,
     dkArg, dkArgShort, dkArgLong:
    todo "toVariable ", src.kind
    deliNone()
  else:
    raise newException(ValueError, "incompatible type: Variable(" & $src.kind & ")")

proc toBoolean*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInteger: DKBool( src.intVal != 0 )
  of dkBoolean: DKBool( src.boolVal )
  of dkNone:    deliFalse()
  else:
    todo "toBoolean ", src.kind
    deliNone()

proc toInteger*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInteger: DKInt( src.intVal )
  #of dkString:  DKInt( int(src.strVal) )
  else:
    todo "toInteger ", src.kind
    deliNone()

proc toPath*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkPath,
     dkString,
     dkStrBlock,
     dkStrLiteral:
    return DKPath( src.strVal )
  of dkIdentifier,
     dkArg, dkArgLong, dkArgShort,
     dkInteger,
     dkBoolean,
     dkArray,
     dkStream:
    todo "toPath ", src.kind
    deliNone()
  else:
    raise newException(ValueError, "incompatible type: Path(" & $src.kind & ")")

proc toArg*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkString,
     dkStrLiteral:
    DKArg(src.strVal)
  of dkArgShort:
    DeliNode(kind: dkArgShort, argName: src.argName)
  of dkArgLong:
    DeliNode(kind: dkArgLong, argName: src.argName)
  else:
    todo "toArg ", src.kind
    deliNone()

proc toArray*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkArray:
    var sons = newSeq[DeliNode]()
    for item in src.sons:
      # should this do an explicit copy?
      sons.add item
    DeliNode(kind: dkArray, sons: sons)
  else:
    todo "toArray ", src.kind
    deliNone()

proc toObject*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkObject:
    # explicit copy needed?
    DeliNode(kind: dkObject, table: src.table)
  else:
    todo "toObject ", src.kind
    deliNone()

proc toRegex*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkRegex:
    DeliNode(kind: dkRegex, pattern: src.pattern)
  of dkString, dkStrLiteral, dkStrBlock, dkArray:
    todo "toRegex ", src.kind
    deliNone()
  else:
    raise newException(ValueError, "incompatible type: Regex(" & $src.kind & ")")

proc toStream*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkStream, dkInteger:
    return DeliNode(kind: dkStream, intVal: src.intVal)
  of dkArray, dkString, dkStrLiteral, dkStrBlock:
    todo "toStream ", src.kind
    deliNone()
  else:
    raise newException(ValueError, "incompatible type: Stream(" & $src.kind & ")")

proc toKind*(src: DeliNode, dest: DeliKind): DeliNode =
  result = case dest
  #of dkString:  toString  src
  of dkIdentifier: toIdentifier src
  of dkVariable:   toVariable   src
  of dkArg,
     dkArgShort,
     dkArgLong:    toArg        src
  of dkPath:       toPath       src
  of dkInteger:    toInteger    src
  of dkBoolean:    toBoolean    src
  of dkArray:      toArray      src
  of dkObject:     toObject     src
  of dkRegex:      toRegex      src
  of dkStream:     toStream     src
  else:
    todo "cast ", src.kind, " as ", dest
    deliNone()
