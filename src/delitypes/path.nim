import std/appdirs
import std/paths
import std/posix
import std/tables
import ../deliast
import common

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
proc nop(path: string): bool = false
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
proc isSame(file1: string, file2: string): bool =         # -ef FILE1 -ef FILE2 #FILE1 and FILE2 have the same device and inode numbers
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

proc DKTime(time: Timespec): DeliNode =
  return DKDecimal(time.tv_sec.int, time.tv_nsec, 9)

proc dStat(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkPath
  let path = arg
  maxarg
  var st = Stat()
  if stat(path.strVal.cstring, st) != 0:
    return deliNone()
  result = DeliObject([
    ("dev",     DKInt(st.st_dev)),
    ("ino",     DKInt(st.st_ino)),
    ("mode",    DKInt(st.st_mode.int)),
    ("nlink",   DKInt(st.st_nlink.int)),
    ("uid",     DKInt(st.st_uid.int)),
    ("gid",     DKInt(st.st_gid.int)),
    ("rdev",    DKInt(st.st_rdev)),
    ("size",    DKInt(st.st_size)),
    ("atime",   DKTime(st.st_atim)),
    ("mtime",   DKTime(st.st_mtim)),
    ("ctime",   DKTime(st.st_ctim)),
    ("blksize", DKInt(st.st_blksize)),
    ("blocks",  DKInt(st.st_blocks)),
  ])

proc dTest(nodes: varargs[DeliNode]): DeliNode =
  argvars
  shift
  result = deliNone()

  let path = arg

  shift
  let op = arg
  case op.kind
  of dkArg,
     dkArgShort,
     dkArgLong:
    let fn1 = case op.argName
    of "b", "block":  isBlock
    of "c", "char":   isChar
    of "d", "dir":    isDir
    of "e", "exists": exists
    of "f", "file":   isRegular
    of "g", "sgid":   isSetGID
    of "G", "group":  isOwnGroup
    of "k", "sticky": isSticky
    of "L", "link":   isLink
    of "N", "unread": isUnread
    of "O", "owner":  isOwnUser
    of "p", "pipe":   isPipe
    of "r", "read":   isReadable
    of "s", "size":   isNonzero
    of "S", "socket": isSocket
    of "u", "suid":   isSetUID
    of "w", "write":  isWriteable
    of "x", "exec":   isExecutable
    else:             nop
    if fn1 != nop:
      return DKBool( fn1(path.strVal) )

    let fn2 = case op.argName
    of "n", "newer":         isNewer
    of "o", "older":         isOlder
    of "i", "equal", "same": isSame
    else:
      raise newException(ValueError, "Unknown test argument: " & $op)

    shift
    let path2 = arg
    return DKBool( fn2(path.strVal, path2.strVal) )

  else:
    echo $op

# file and directory operations
proc dChdir(nodes: varargs[DeliNode]): DeliNode =
  var arg: DeliNode
  var arg_i = 0
  nextarg dkPath
  result = DKBool( chdir(arg.strVal.cstring) == 0 )

proc dPwd(nodes: varargs[DeliNode]): DeliNode =
  noargs
  result = DKPath($getCurrentDir())

proc dHome(nodes: varargs[DeliNode]): DeliNode =
  noargs
  result = DKPath($getHomeDir())

let PathFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "stat": dStat,
  "test": dTest,
  "pwd": dPwd,
  "home": dHome,
  "chdir": dChdir,
  #"mkdir": dMkdir,
  #"unlink": dUnlink,
  #"rename": dRename,
  #"chown": dChown,
  #"chmod": dChmod,
  #"symlink": dSymlink,
}.toTable
