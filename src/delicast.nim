import os
import std/strutils
import std/tables
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
  of dkString,
     dkStrLiteral,
     dkStrBlock:    DKBool( src.strVal.len > 0 )
  #of dkIdentifier: # TODO check for existance via engine
  #of dkVariable: # TODO check dereference is not None
  #of dkArg, dkArgShort, dkArgLong: # TODO check engine has variables
  of dkPath:        DKBool(fileExists(src.strVal))
  of dkInteger:     DKBool( src.intVal != 0 )
  of dkBoolean:     DKBool( src.boolVal )
  of dkArray:       DKBool( src.sons.len > 0 )
  of dkObject:      DKBool( src.table.len > 0 )
  of dkRegex:
    raise newException(ValueError, "incompatible type: Boolean(Regex)")
  #of dkStream:      DKBool( src.intVal in engine.fds )
  of dkNone:        deliFalse()
  else:
    todo "toBoolean ", src.kind
    deliNone()

proc toInteger*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkInteger:    DKInt( src.intVal )
  of dkStream:     DKInt(src.intVal)
  of dkIdentifier,
     dkVariable,
     dkArg, dkArgLong, dkArgShort,
     dkPath,
     dkRegex:
    raise newException(ValueError, "incompatible type: Integer(" & $src.kind & ")")
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
     dkStrLiteral: DKArg(src.strVal)
  of dkIdentifier: DKArg(src.id)
  of dkVariable:   DKArg(src.varName)
  of dkArgShort:   DeliNode(kind: dkArgShort, argName: src.argName)
  of dkArgLong:    DeliNode(kind: dkArgLong, argName: src.argName)
  else:
    raise newException(ValueError, "incompatible type: Path(" & $src.kind & ")")

proc toArray*(src: DeliNode): DeliNode =
  result = case src.kind
  of dkArray:
    var sons = newSeq[DeliNode]()
    for item in src.sons: # should this do an explicit copy?
      sons.add item
    DeliNode(kind: dkArray, sons: sons)
  of dkObject:
    var sons = newSeq[DeliNode]()
    for key in src.table.keys: # should this do an explicit copy?
      sons.add DeliNode(kind: dkArray, sons: @[DKStr(key), src.table[key]])
    DeliNode(kind: dkArray, sons: sons)
  of dkString,
     dkStrLiteral:
    var sons = newSeq[DeliNode]()
    for str in src.strVal.split(' '):
      sons.add DKStr(str)
    DeliNode(kind: dkArray, sons: sons)
  of dkStrBlock:
    var sons = newSeq[DeliNode]()
    for str in src.strVal.split('\n'):
      sons.add DKStr(str)
    DeliNode(kind: dkArray, sons: sons)
  of dkIdentifier,
     dkVariable,
     dkArg,
     dkArgShort,
     dkArgLong,
     dkInteger:     DeliNode(kind: dkArray, sons: @[src])
  of dkStream:      raise newException(ValueError, "incompatible type: Array(Stream)")
  else:
    todo "toArray ", src.kind
    deliNone()

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
  of dkObject:     DeliNode(kind: dkObject, table: src.table) # explicit copy needed?
  of dkIdentifier: DeliObject([(src.id, deliNone())]) # TODO evaluate value
  of dkVariable:   DeliObject([(src.varName, deliNone())]) # TODO evaluate value
  of dkArg:        DeliObject([(src.argName, deliNone())]) # TODO evaluate value
  of dkInteger:    DeliObject([("int", DKInt(src.intVal))])
  of dkBoolean:    DeliObject([("bool", DKBool(src.boolVal))])
  of dkStream:     DeliObject([($src.intval, deliNone())])
  else:
    raise newException(ValueError, "incompatible type: Regex(" & $src.kind & ")")

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
