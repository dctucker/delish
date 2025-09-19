import std/posix
import std/tables
import deliast

# whether a mode has a bit set
func has(m: Mode, b: cint): bool =
  return (m.cint and b) != 0
#
## whether a file has a mode set
#proc has(filename: string, check: proc(m: Mode): bool): bool {.gcsafe.} =
#  var st = Stat()
#  return stat(filename.cstring, st) == 0 and check(st.st_mode)

# whether a file has a bit set
proc has(filename: string, bit: cint): bool =
  var st = Stat()
  return stat(filename.cstring, st) == 0 and ((st.st_mode.int and bit) != 0)

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
proc isBlock(filename: string): bool = filename.has(S_IFBLK)   # -b FILE #FILE exists and is block special
proc isChar(filename: string): bool  = filename.has(S_IFCHR)   # -c FILE #FILE exists and is character special
proc isDir(filename: string): bool   = filename.has(S_IFDIR)   # -d FILE #FILE exists and is a directory
proc exists(filename: string): bool  =                         # -e FILE #FILE exists
  var st = Stat()
  return stat(filename, st) == 0
proc isRegular(filename: string): bool = filename.has(S_IFREG) # -f FILE #FILE exists and is a regular file
proc isSetGID(filename: string): bool = filename.has(S_ISGID)  # -g FILE #FILE exists and is set-group-ID
proc isOwnGroup(filename: string): bool =                      # -G FILE #FILE exists and is owned by the effective group ID
  var st = Stat()
  return stat(filename, st) == 0 and st.st_gid == myGID()
proc isSticky(filename: string): bool = filename.has(S_ISVTX)  # -k FILE #FILE exists and has its sticky bit set
proc isLink(filename: string): bool   = filename.has(S_IFLNK)  # -L FILE #FILE exists and is a symbolic link
proc isUnread(filename: string): bool =
  var st = Stat()
  return stat(filename, st) == 0 and st.st_mtim > st.st_atim   # -N FILE #FILE exists and has been modified since it was last read
proc isOwnUser(filename: string): bool =                       # -O FILE #FILE exists and is owned by the effective user ID
  var st = Stat()
  return stat(filename, st) == 0 and st.st_uid == myUID()
proc isPipe(filename: string): bool  = filename.has(S_IFIFO)   # -p FILE #FILE exists and is a named pipe
proc isReadable(filename: string): bool =                      # -r FILE #FILE exists and the user has read access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IROTH)) or
    (st.st_mode.has(S_IRUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IRGRP) and (st.st_gid == myGID()))
  )
proc isNonzero(filename: string): bool =                       # -s FILE #FILE exists and has a size greater than zero
  var st = Stat()
  return stat(filename, st) == 0 and (
    st.st_size > 0
  )
proc isSocket(filename: string): bool = filename.has(S_IFSOCK) # -S FILE #FILE exists and is a socket
proc isTty(fd: int): bool = isatty(fd.cint) != 0               # -t FD   #FD is opened on a terminal
proc isSetUID(filename: string): bool  = filename.has(S_ISUID) # -u FILE #FILE exists and its set-user-ID bit is set
proc isWriteable(filename: string): bool =                     # -w FILE #FILE exists and the user has write access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IWOTH)) or
    (st.st_mode.has(S_IWUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IWGRP) and (st.st_gid == myGID()))
  )
proc isExecutable(filename: string): bool =                    # -x FILE #FILE exists and the user has execute (or search) access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IXOTH)) or
    (st.st_mode.has(S_IXUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IXGRP) and (st.st_gid == myGID()))
  )
proc isSameFile(file1: string, file2: string): bool =          # -ef FILE1 -ef FILE2 #FILE1 and FILE2 have the same device and inode numbers
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_dev == st2.st_dev and
    st1.st_ino == st2.st_ino
  )
proc isNewer(file1: string, file2: string): bool =             # -nt FILE1 -nt FILE2 #FILE1 is newer (modification date) than FILE2
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_mtim > st2.st_mtim
  )
proc isOlder(file1: string, file2: string): bool =             # -ot FILE1 -ot FILE2 #FILE1 is older than FILE2
  var st1 = Stat()
  var st2 = Stat()
  return (
    stat(file1, st1) == 0 and
    stat(file2, st2) == 0 and
    st1.st_mtim < st2.st_mtim
  )

let PathFunctions: Table[string,proc(filename: string): bool {.nimcall.} ] = {
  "b": isBlock,
  "c": isChar,
  "d": isDir,
  "e": exists,
  "f": isRegular,
  "g": isSetGID,
  "G": isOwnGroup,
  "k": isSticky,
  "L": isLink,
  "N": isUnread,
  "O": isOwnUser,
  "p": isPipe,
  "r": isReadable,
  "s": isNonzero,
  "S": isSocket,
  #"t": isTty, # this belongs in StreamFunctions
  "u": isSetUID,
  "w": isWriteable,
  "x": isExecutable,
}.toTable

proc pathFunction*(node: DeliNode, op: string): DeliNode =
  assert node.kind == dkPath
  let path = node.strVal
  if op in PathFunctions:
    return DKBool(PathFunctions[op](path))
  else:
    deliNone()

