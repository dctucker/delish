import std/[
  algorithm,
  #appdirs,
  os,
  #paths,
  posix,
  tables,
  sequtils,
]
import ./common

# whether a mode has a bit set
func has(m: Mode, b: cint): bool =
  return (m.cint and b) != 0

## whether a file has mode criteria
template check(st: Stat, check: untyped): bool =
  check(st.st_mode)

# whether a file has a bit set
proc has(st: Stat, bit: cint): bool =
  return (st.st_mode.int and bit) != 0

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
proc nop1(st: Stat): bool = false
proc nop2(st1, st2: Stat): bool = false
proc isBlock(st: Stat): bool = st.check(S_ISBLK)        # -b FILE #FILE exists and is block special
proc isChar(st: Stat): bool  = st.check(S_ISCHR)        # -c FILE #FILE exists and is character special
proc isDir(st: Stat): bool   = st.check(S_ISDIR)        # -d FILE #FILE exists and is a directory
proc exists(st: Stat): bool  = st.st_nlink > 0          # -e FILE #FILE exists
proc isRegular(st: Stat): bool = st.check(S_ISREG)      # -f FILE #FILE exists and is a regular file
proc isSetGID(st: Stat): bool = st.has(S_ISGID)         # -g FILE #FILE exists and is set-group-ID
proc isOwnGroup(st: Stat): bool = st.st_gid == myGID()  # -G FILE #FILE exists and is owned by the effective group ID
proc isSticky(st: Stat): bool = st.has(S_ISVTX)         # -k FILE #FILE exists and has its sticky bit set
proc isLink(st: Stat): bool   = st.check(S_ISLNK)       # -L FILE #FILE exists and is a symbolic link
proc isUnread(st: Stat): bool = st.st_mtim > st.st_atim # -N FILE #FILE exists and has been modified since it was last read
proc isOwnUser(st: Stat): bool = st.st_uid == myUID()   # -O FILE #FILE exists and is owned by the effective user ID
proc isPipe(st: Stat): bool  = st.check(S_ISFIFO)       # -p FILE #FILE exists and is a named pipe
proc isReadable(st: Stat): bool =                       # -r FILE #FILE exists and the user has read access
  return (
    (st.st_mode.has(S_IROTH)) or
    (st.st_mode.has(S_IRUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IRGRP) and (st.st_gid == myGID()))
  )
proc isNonzero(st: Stat): bool =                        # -s FILE #FILE exists and has a size greater than zero
  return (
    st.st_size > 0
  )
proc isSocket(st: Stat): bool = st.check(S_ISSOCK)      # -S FILE #FILE exists and is a socket
proc isTty(fd: int): bool = isatty(fd.cint) != 0        # -t FD   #FD is opened on a terminal
proc isSetUID(st: Stat): bool  = st.has(S_ISUID)        # -u FILE #FILE exists and its set-user-ID bit is set
proc isWriteable(st: Stat): bool =                      # -w FILE #FILE exists and the user has write access
  return (
    (st.st_mode.has(S_IWOTH)) or
    (st.st_mode.has(S_IWUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IWGRP) and (st.st_gid == myGID()))
  )
proc isExecutable(st: Stat): bool =                     # -x FILE #FILE exists and the user has execute (or search) access
  return (
    (st.st_mode.has(S_IXOTH)) or
    (st.st_mode.has(S_IXUSR) and (st.st_uid == myUID())) or
    (st.st_mode.has(S_IXGRP) and (st.st_gid == myGID()))
  )
proc isSame(st1, st2: Stat): bool =                     # -ef FILE1 -ef FILE2 #FILE1 and FILE2 have the same device and inode numbers
  return (
    st1.st_dev == st2.st_dev and
    st1.st_ino == st2.st_ino
  )
proc isNewer(st1, st2: Stat): bool =                    # -nt FILE1 -nt FILE2 #FILE1 is newer (modification date) than FILE2
  return (
    st1.st_mtim > st2.st_mtim
  )
proc isOlder(st1, st2: Stat): bool =                    # -ot FILE1 -ot FILE2 #FILE1 is older than FILE2
  return (
    st1.st_mtim < st2.st_mtim
  )

#const modeFuncs = {"b","c","d","e","f","g","k","L","p","r","S","u","w","x"}
proc testFunc1(op: string): proc(st: Stat): bool {.nimcall.} =
  result = case op
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
  else:             nop1

proc testFunc2(op: string): proc(st1, st2: Stat): bool {.nimcall.} =
  let fn2 = case op
  of "n", "newer":         isNewer
  of "o", "older":         isOlder
  of "i", "equal", "same": isSame
  else: nop2

proc DKTime(time: Timespec): DeliNode =
  return DKDecimal(time.tv_sec.int, time.tv_nsec, 9)

converter toTimespec(decVal: Decimal): Timespec =
  result.tv_sec = decVal.whole.Time
  result.tv_nsec = decVal.fraction

converter toStat(node: DeliNode): Stat =
  result.st_dev       = node.table["dev"].intVal.Dev
  result.st_ino       = node.table["ino"].intVal.Ino
  result.st_mode      = node.table["mode"].intVal.Mode
  result.st_nlink     = node.table["nlink"].intVal.Nlink
  result.st_uid       = node.table["uid"].intVal.Uid
  result.st_gid       = node.table["gid"].intVal.Gid
  result.st_rdev      = node.table["rdev"].intVal.Dev
  result.st_size      = node.table["size"].intVal.Off
  result.st_atim      = node.table["atime"].decVal.toTimespec
  result.st_mtim      = node.table["mtime"].decVal.toTimespec
  result.st_ctim      = node.table["ctime"].decVal.toTimespec
  result.st_blksize   = node.table["blksize"].intVal.Blksize
  result.st_blocks    = node.table["blocks"].intVal.Blkcnt

converter toStatMode(node: DeliNode): Stat =
  result.st_mode      = node.table["mode"].intVal.Mode



proc dTest(nodes: varargs[DeliNode]): DeliNode =
  #echo "dTest ", nodes
  argvars
  shift
  result = deliNone()

  case arg.kind
  of dkObject: # hope it's a stat object
    let obj = arg

    shift
    express
    let op = arg
    case op.kind
    of dkArg,
       dkArgShort,
       dkArgLong:
      let fn1 = testFunc1(op.argName)
      if fn1 != nop1:
        return DKBool( fn1(obj.toStat) )

      let fn2 = testFunc2(op.argName)
      if fn2 != nop2:
        shift
        let obj2 = arg
        return DKBool( fn2(obj.toStat, obj2.toStat) )

      raise newException(ValueError, "Unknown test argument: " & $op & " / " & op.argName)

    else:
      raise newException(ValueError, "Unsupported test argument: " & op.kind.name & ":" & $op)

  of dkPath:
    let path = arg

    shift
    express
    let op = arg
    case op.kind
    of dkArg,
       dkArgShort,
       dkArgLong:

      let fn1 = testFunc1(op.argName)
      if fn1 != nop1:
        var st = Stat()
        if lstat(path.strVal.cstring, st) == 0:
          return DKBool( fn1(st) )
        else:
          return DKBool( false )

      let fn2 = testFunc2(op.argName)
      if fn2 != nop2:
        shift
        let path2 = arg
        var st1 = Stat()
        var st2 = Stat()
        if lstat(path.strVal.cstring, st1) == 0:
          if lstat(path2.strVal.cstring, st2) == 0:
            return DKBool( fn2(st1, st2) )
        return DKBool( false )

      raise newException(ValueError, "Unknown test argument: " & $op & " / " & op.argName)

    else:
      raise newException(ValueError, "Unsupported test argument: " & op.kind.name & ":" & $op)
  else: discard

converter toObject(st: Stat): DeliNode =
  result = DeliObject([
    ("dev",     DKInt(st.st_dev.int)),
    ("ino",     DKInt(st.st_ino.int)),
    ("mode",    DKInt(st.st_mode.int)),
    ("nlink",   DKInt(st.st_nlink.int)),
    ("uid",     DKInt(st.st_uid.int)),
    ("gid",     DKInt(st.st_gid.int)),
    ("rdev",    DKInt(st.st_rdev.int)),
    ("size",    DKInt(st.st_size)),
    ("atime",   DKTime(st.st_atim)),
    ("mtime",   DKTime(st.st_mtim)),
    ("ctime",   DKTime(st.st_ctim)),
    ("blksize", DKInt(st.st_blksize)),
    ("blocks",  DKInt(st.st_blocks)),
  ])
  result.table["test"] = DKCallable(dTest, @[result])

proc statObj(path: DeliNode): DeliNode {.inline.} =
  var st = Stat()
  if lstat(path.strVal.cstring, st) == 0:
    result = st.toObject
    result.table["path"] = path
    return result
  return deliNone()

proc dStat(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    node.statObj

proc dirname(path: string): string  =
  var pathstr = path
  prepareMutation(pathstr)
  var cstr = pathstr.cstring
  cstr = cstr.dirname
  return $cstr

proc basename(path: string): string  =
  var pathstr = path
  prepareMutation(pathstr)
  var cstr = pathstr.cstring
  cstr = cstr.basename
  return $cstr

proc dDirname(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    DKPath(nodes[0].strVal.dirname)

proc dBasename(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    DKPath(node.strVal.basename)

# file and directory operations
proc dChdir(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkPath
  result = DKBool( chdir(arg.strVal.cstring) == 0 )

proc dPwd(nodes: varargs[DeliNode]): DeliNode =
  noargs
  result = DKPath($os.getCurrentDir())

proc dHome(nodes: varargs[DeliNode]): DeliNode =
  noargs
  result = DKPath($os.getHomeDir())

type PathEntry = tuple[kind: PathComponent, path: string]

proc dListDir(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextarg dkPath
  let path = arg

  var opt = DKArg("0")
  var long = false
  if arg_i < nodes.len:
    arg = nodes[arg_i]
    arg_i += 1
    express
    opt = arg

  if opt.argName == "l":
    long = true

  result = DK(dkArray)
  result.sons = walkDir(path.strVal, relative=true).toSeq.sorted(
    proc(e1, e2: PathEntry): int =
      let s1 = $(e1.kind) & e1.path
      let s2 = $(e2.kind) & e2.path
      return system.cmp[string](s1, s2)
  ).map(
    proc(e: PathEntry): DeliNode =
      if long:
        var st = Stat()
        discard lstat(e.path.cstring, st)
        result = st.toObject
        result.table["path"] = DKPath(e.path)
      else:
        result = DKPath(e.path)
  )

let PathFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "test": dTest,
  "pwd": dPwd,
  "home": dHome,
  "chdir": dChdir,
  "stat": dStat,
  "dirname": dDirname,
  "basename": dBasename,
  "list": dListDir,
  #"mkdir": dMkdir,
  #"unlink": dUnlink,
  #"rename": dRename,
  #"chown": dChown,
  #"chmod": dChmod,
  #"symlink": dSymlink,
}.toTable
