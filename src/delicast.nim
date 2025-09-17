import deliast

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
  of dkString,
     dkStrLiteral:
    return DKPath( src.strVal )
  else:
    todo "toPath ", src.kind
    deliNone()

proc toKind*(src: DeliNode, dest: DeliKind): DeliNode =
  result = case dest
  of dkInteger: toInteger src
  of dkBoolean: toBoolean src
  of dkPath:    toPath    src
  #of dkString:  toString  src
  else:
    todo "cast ", src.kind, " as ", dest
    deliNone()
