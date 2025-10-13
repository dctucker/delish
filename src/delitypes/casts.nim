import
  std/[
    os,
    strutils,
    tables,
    times,
  ],
  ./[
    common,
    parse,
    string
  ]

proc Incompatible(kind: DeliKind, node: DeliNode): ref Exception =
  let k1 = kind.name
  let k2 = node.kind.name
  return newException(ValueError, "incompatible type: " & k1 & "(" & k2 & ")")

proc toIdentifier*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkIdentifier: DKId(src.id)
  of dkString:     DKId(src.strVal)
  of dkVariable:   DKId(src.varName)
  of dkArg,
     dkArgShort,
     dkArgLong:    DKId(src.argName) # TODO check this
  else: raise Incompatible(dkIdentifier, src)

proc toVariable*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkVariable:
    DKVar(src.varName)
  of dkString,
     dkIdentifier,
     dkArg, dkArgShort, dkArgLong:
    todo "toVariable ", src.kind
    deliNone()
  else: raise Incompatible(dkVariable, src)

proc toBoolean*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkString,
     dkStrLiteral,
     dkStrBlock:    DKBool( src.strVal.len > 0 )
  of dkIdentifier:  DKLazy(DKNotNone(src)) # TODO check for existance via engine
  of dkVariable:    DKLazy(DKNotNone(src)) # TODO check dereference is not None
  of dkArg,
     dkArgShort,
     dkArgLong:     DKLazy(DKNotNone(src)) # TODO check engine has variables
  of dkPath:        DKBool(src.strVal.fileExists or src.strVal.dirExists)
  of dkInt8,
     dkInt10,
     dkInt16,
     dkInteger:     DKBool( src.intVal != 0 )
  of dkBoolean:     DKBool( src.boolVal )
  of dkArray:       DKBool( src.sons.len > 0 )
  of dkObject:      DKBool( src.table.len > 0 )
  of dkRegex:       raise Incompatible(dkBoolean, src)
  of dkStream:      DKLazy(DKNotNone(src)) # TODO src.intVal in engine.fds
  of dkNone:        deliFalse()
  else:
    todo "toBoolean ", src.kind
    deliNone()

proc toInteger*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInt8:       DKInt8( src.intVal )
  of dkInt10:      DKInt10( src.intVal )
  of dkInt16:      DKInt16( src.intVal )
  of dkInteger:    DKInt( src.intVal )
  of dkStream:     DKInt(src.intVal)
  of dkBoolean:    DKInt(if src.boolVal: 1 else: 0)
  of dkString:     DKInt(src.strVal.parseInteger)
  of dkIdentifier,
     dkVariable,
     dkArg, dkArgLong, dkArgShort,
     dkPath,
     dkRegex:      raise Incompatible(dkInteger, src)
  #of dkString:  DKInt( int(src.strVal) )
  of dkArray:      DKInt(src.sons.len)
  of dkObject:     DKInt(src.table.len)
  else:
    todo "toInteger ", src.kind
    deliNone()

proc toDecimal*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInt8,
     dkInt10,
     dkInt16,
     dkInteger: DKDecimal(src.intVal, 0, 0)
  of dkDateTime: DKDecimal(src.dtVal.toTime().toUnix(), src.dtVal.nanosecond, 9)
  else:
    todo "toDecimal ", src.kind
    deliNone()

proc toDateTime*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkString: DKDateTime(src.strVal)
  of dkDecimal: DKDateTime(src.decVal)
  else:
    todo "toDateTime ", src.kind
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
     dkInt8,
     dkInt10,
     dkInt16,
     dkInteger,
     dkBoolean,
     dkArray,
     dkStream:
    todo "toPath ", src.kind
    deliNone()
  else: raise Incompatible(dkPath, src)

proc toArg*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkString,
     dkStrLiteral: DKArg(src.strVal)
  of dkIdentifier: DKArg(src.id)
  of dkVariable:   DKArg(src.varName)
  of dkArgShort:   DKArgShort(src.argName)
  of dkArgLong:    DKArgLong(src.argName)
  else: raise Incompatible(dkPath, src)

proc toArray*(src: DeliNode): DeliNode =
  result = DK(dkArray)
  case src.kind
  of dkArray:
    for item in src.sons: # should this do an explicit copy?
      result.addSon item
  of dkObject:
    for key in src.table.keys: # should this do an explicit copy?
      result.addSon DK(dkArray, DKStr(key), src.table[key])
  of dkString,
     dkStrLiteral:
    for str in src.strVal.split(' '):
      result.addSon DKStr(str)
  of dkStrBlock:
    for str in src.strVal.split('\n'):
      result.addSon DKStr(str)
  of dkIdentifier,
     dkVariable,
     dkArg,
     dkArgShort,
     dkArgLong,
     dkInt8,
     dkInt10,
     dkInt16,
     dkInteger:
    result.addSon src
  #of dkRegex:
  #  result.addSons src.pattern.rules
  else: raise Incompatible(dkArray, src)

proc toObject*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkString,
     dkStrLiteral,
     dkStrBlock:
    todo "toObject parse ", src.kind
    deliNone()
  of dkArray:
    var obj = DeliObject([])
    var i = 0
    for item in src.sons:
      obj.table[$i] = item
      i += 1
    obj
  of dkObject:     DKObject(src.table) # explicit copy needed?
  of dkIdentifier: DeliObject([(src.id     , DKLazy(src))]) # TODO evaluate value
  of dkVariable:   DeliObject([(src.varName, DKLazy(src))]) # TODO evaluate value
  of dkArg:        DeliObject([(src.argName, DKLazy(src))]) # TODO evaluate value
  of dkInt8,
     dkInt10,
     dkInt16,
     dkInteger:    DeliObject([("int", DKInt(src.intVal))])
  of dkBoolean:    DeliObject([("bool", DKBool(src.boolVal))])
  of dkStream:     DeliObject([($src.intval, deliNone())])
  else: raise Incompatible(dkObject, src)

proc toRegex*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkRegex:
    DKRegex(src.pattern)
  of dkString, dkStrLiteral, dkStrBlock, dkArray:
    todo "toRegex ", src.kind
    deliNone()
  else: raise Incompatible(dkRegex, src)

proc toStream*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInt8,
     dkInt10,
     dkInt16,
     dkStream,
     dkInteger:
    return DKStream( src.intVal)
  of dkArray, dkString, dkStrLiteral, dkStrBlock:
    todo "toStream ", src.kind
    deliNone()
  else: raise Incompatible(dkStream, src)

proc toKind*(src: DeliNode, dest: DeliKind): DeliNode =
  if src.kind == dest:
    result = src
    return result # TODO: verify this is a copy
  result = case dest
  of dkString:     asString     src
  of dkIdentifier: toIdentifier src
  of dkVariable:   toVariable   src
  of dkArg,
     dkArgShort,
     dkArgLong:    toArg        src
  of dkPath:       toPath       src
  of dkInteger:    toInteger    src
  of dkDecimal:    toDecimal    src
  of dkDateTime:   toDateTime   src
  of dkBoolean:    toBoolean    src
  of dkArray:      toArray      src
  of dkObject:     toObject     src
  of dkRegex:      toRegex      src
  of dkStream:     toStream     src
  else:
    todo "cast ", src.kind, " as ", dest
    deliNone()
