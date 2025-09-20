import std/posix
import std/tables
import deliast

# whether a mode has a bit set
func has(m: Mode, b: cint): bool =
  return (m.cint and b) != 0
#
## whether a file has a mode set
#proc has(path: string, check: proc(m: Mode): bool): bool {.gcsafe.} =
#  var st = Stat()
#  return stat(path.cstring, st) == 0 and check(st.st_mode)

# whether a file has a bit set
proc has(path: string, bit: cint): bool =
  var st = Stat()
  return stat(path.cstring, st) == 0 and ((st.st_mode.int and bit) != 0)

# comparison operators not present in std/posix
proc `>`(t1, t2: Timespec): bool =
  let ds = t1.tv_sec - t2.tv_sec
  return (ds.int > 0) or (ds.int == 0 and t1.tv_nsec > t2.tv_nsec)
proc `<`(t1, t2: Timespec): bool =
  let ds = t1.tv_sec - t2.tv_sec
  return (ds.int < 0) or (ds.int == 0 and t1.tv_nsec < t2.tv_nsec)

proc myUID(): Gid =
  {.cast(noSideEffect).}:
    return getgid()
proc myGID(): Gid =
  {.cast(noSideEffect).}:
    return getgid()

# functions that perform POSIX `test` command checks
proc isBlock(path: string): bool = path.has(S_IFBLK)      # -b FILE #FILE exists and is block special
proc isChar(path: string): bool  = path.has(S_IFCHR)      # -c FILE #FILE exists and is character special
proc isDir(path: string): bool   = path.has(S_IFDIR)      # -d FILE #FILE exists and is a directory
proc exists(path: string): bool  =                        # -e FILE #FILE exists
  var st = Stat()
  return stat(path, st) == 0
proc isRegular(path: string): bool = path.has(S_IFREG)    # -f FILE #FILE exists and is a regular file
proc isSetGID(path: string): bool = path.has(S_ISGID)     # -g FILE #FILE exists and is set-group-ID
proc isOwnGroup(path: string): bool =                     # -G FILE #FILE exists and is owned by the effective group ID
  var st = Stat()
  return stat(path, st) == 0 and st.st_gid == myGID()
proc isSticky(path: string): bool = path.has(S_ISVTX)     # -k FILE #FILE exists and has its sticky bit set
proc isLink(path: string): bool   = path.has(S_IFLNK)     # -L FILE #FILE exists and is a symbolic link
proc isUnread(path: string): bool =
  var st = Stat()
  return stat(path, st) == 0 and st.st_mtim > st.st_atim  # -N FILE #FILE exists and has been modified since it was last read
proc isOwnUser(path: string): bool =                      # -O FILE #FILE exists and is owned by the effective user ID
  var st = Stat()
  return stat(path, st) == 0 and st.st_uid == myUID()
proc isPipe(path: string): bool  = path.has(S_IFIFO)      # -p FILE #FILE exists and is a named pipe
proc isReadable(path: string): bool =                     # -r FILE #FILE exists and the user has read access
  var st = Stat()
  return stat(path, st) == 0 and (
    (st.st_mode.has(S_IROTH)) or
    (st.st_mode.has(S_IRUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IRGRP) and (st.st_gid == myGID()))
  )
proc isNonzero(path: string): bool =                      # -s FILE #FILE exists and has a size greater than zero
  var st = Stat()
  return stat(path, st) == 0 and (
    st.st_size > 0
  )
proc isSocket(path: string): bool = path.has(S_IFSOCK)    # -S FILE #FILE exists and is a socket
proc isTty(fd: int): bool = isatty(fd.cint) != 0               # -t FD   #FD is opened on a terminal
proc isSetUID(path: string): bool  = path.has(S_ISUID)    # -u FILE #FILE exists and its set-user-ID bit is set
proc isWriteable(path: string): bool =                    # -w FILE #FILE exists and the user has write access
  var st = Stat()
  return stat(path, st) == 0 and (
    (st.st_mode.has(S_IWOTH)) or
    (st.st_mode.has(S_IWUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IWGRP) and (st.st_gid == myGID()))
  )
proc isExecutable(path: string): bool =                   # -x FILE #FILE exists and the user has execute (or search) access
  var st = Stat()
  return stat(path, st) == 0 and (
    (st.st_mode.has(S_IXOTH)) or
    (st.st_mode.has(S_IXUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IXGRP) and (st.st_gid == myGID()))
  )
proc isSameFile(file1: string, file2: string): bool =     # -ef FILE1 -ef FILE2 #FILE1 and FILE2 have the same device and inode numbers
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_dev == st2.st_dev and
    st1.st_ino == st2.st_ino
  )
proc isNewer(file1: string, file2: string): bool =        # -nt FILE1 -nt FILE2 #FILE1 is newer (modification date) than FILE2
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_mtim > st2.st_mtim
  )
proc isOlder(file1: string, file2: string): bool =        # -ot FILE1 -ot FILE2 #FILE1 is older than FILE2
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_mtim < st2.st_mtim
  )

template liftDeliProc1(fn, name): untyped =
  proc name(node: DeliNode): DeliNode {.nimcall.} =
    if node.kind != dkPath:
      return deliNone()
    let bres = fn(node.strVal)
    return DeliNode(kind: dkBoolean, boolVal: bres)

liftDeliProc1(isBlock,     disBlock)
liftDeliProc1(isChar,      disChar)
liftDeliProc1(isDir,       disDir)
liftDeliProc1(exists,      dexists)
liftDeliProc1(isRegular,   disRegular)
liftDeliProc1(isSetGID,    disSetGID)
liftDeliProc1(isOwnGroup,  disOwnGroup)
liftDeliProc1(isSticky,    disSticky)
liftDeliProc1(isLink,      disLink)
liftDeliProc1(isUnread,    disUnread)
liftDeliProc1(isOwnUser,   disOwnUser)
liftDeliProc1(isPipe,      disPipe)
liftDeliProc1(isReadable,  disReadable)
liftDeliProc1(isNonzero,   disNonzero)
liftDeliProc1(isSocket,    disSocket)
liftDeliProc1(isSetUID,    disSetUID)
liftDeliProc1(isWriteable, disWriteable)
liftDeliProc1(isExecutable,disExecutable)

let PathFunctions: Table[string, proc(node: DeliNode): DeliNode {.nimcall.} ] = {
  "b": disBlock,
  "c": disChar,
  "d": disDir,
  "e": dexists,
  "f": disRegular,
  "g": disSetGID,
  "G": disOwnGroup,
  "k": disSticky,
  "L": disLink,
  "N": disUnread,
  "O": disOwnUser,
  "p": disPipe,
  "r": disReadable,
  "s": disNonzero,
  "S": disSocket,
  #"t": disTty, # this belongs in StreamFunctions
  "u": disSetUID,
  "w": disWriteable,
  "x": disExecutable,
}.toTable

#proc disEqualTo(node: DeliNode): DeliNode {.nimcall.} =
#  #in:
#  # FunctionCall(
#  #   VarDeref:VarDeref( Variable:file Identifier:nt )
#  #   Expr:VarDeref ( VarDeref( Variable:file2 ) )
#  # ))
#  #
#  #out:
#  # DK(dkFunctionCall, DKId(node.id), path1, path2)
#
#let PathFunctions2: Table[string, proc(node: DeliNode): DeliNode {.nimcall.} ] = {
#  "ef": disEqualTo,
#  "nt": disNewerThan,
#  "ot": disOlderThan,
#}

proc pathFunction*(node: DeliNode, op: DeliNode): DeliNode =
  assert node.kind == dkPath
  assert op.kind == dkIdentifier
  result = if op.id in PathFunctions:
    PathFunctions[op.id](node)
  else:
    deliNone()

