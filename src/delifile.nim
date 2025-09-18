import std/posix

# whether a mode has a bit set
proc has(m: Mode, b: cint): bool =
  return (m.cint and b) != 0

# whether a file has a mode set
proc has(filename: string, check: proc(m: Mode): bool): bool =
  var st = Stat()
  return stat(filename.cstring, st) == 0 and check(st.st_mode)

# whether a file has a bit set
proc has(filename: string, bit: int): bool =
  var st = Stat()
  return stat(filename.cstring, st) == 0 and ((st.st_mode.int and bit) != 0)

# comparison operators not present in std/posix
proc `>`(t1, t2: Timespec): bool =
  let ds = t1.tv_sec - t2.tv_sec
  return (ds.int > 0) or (ds.int == 0 and t1.tv_nsec > t2.tv_nsec)
proc `<`(t1, t2: Timespec): bool =
  let ds = t1.tv_sec - t2.tv_sec
  return (ds.int < 0) or (ds.int == 0 and t1.tv_nsec < t2.tv_nsec)

# functions that perform POSIX `test` command checks
proc isBlock(filename: string): bool = filename.has(S_ISBLK)   # -b FILE #FILE exists and is block special
proc isChar(filename: string): bool  = filename.has(S_ISCHR)   # -c FILE #FILE exists and is character special
proc isDir(filename: string): bool   = filename.has(S_ISDIR)   # -d FILE #FILE exists and is a directory
proc exists(filename: string): bool  =                         # -e FILE #FILE exists
  var st = Stat()
  return stat(filename, st) == 0
proc isReg(filename: string): bool   = filename.has(S_ISREG)   # -f FILE #FILE exists and is a regular file
proc isSetGID(filename: string): bool = filename.has(S_ISGID)  # -g FILE #FILE exists and is set-group-ID
proc isGroupOwn(filename: string): bool =                      # -G FILE #FILE exists and is owned by the effective group ID
  var st = Stat()
  return stat(filename, st) == 0 and st.st_gid == getgid()
proc isSticky(filename: string): bool = filename.has(S_ISVTX)  # -k FILE #FILE exists and has its sticky bit set
proc isLink(filename: string): bool   = filename.has(S_ISLNK)  # -L FILE #FILE exists and is a symbolic link
proc isUnread(filename: string): bool =
  var st = Stat()
  return stat(filename, st) == 0 and st.st_mtim > st.st_atim   # -N FILE #FILE exists and has been modified since it was last read
proc isUserOwn(filename: string): bool =                       # -O FILE #FILE exists and is owned by the effective user ID
  var st = Stat()
  return stat(filename, st) == 0 and st.st_uid == getuid()
proc isPipe(filename: string): bool  = filename.has(S_ISFIFO)  # -p FILE #FILE exists and is a named pipe
proc isReadable(filename: string): bool =                      # -r FILE #FILE exists and the user has read access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IROTH)) or
    (st.st_mode.has(S_IRUSR) and (st.st_uid == getuid())) or
    (st.st_mode.has(S_IRGRP) and (st.st_gid == getgid()))
  )
proc isNonzero(filename: string): bool =                       # -s FILE #FILE exists and has a size greater than zero
  var st = Stat()
  return stat(filename, st) == 0 and (
    st.st_size > 0
  )
proc isSocket(filename: string): bool = filename.has(S_ISSOCK) # -S FILE #FILE exists and is a socket
proc isTty(fd: int): bool = isatty(fd.cint) != 0               # -t FD   #FD is opened on a terminal
proc isSetUID(filename: string): bool  = filename.has(S_ISUID) # -u FILE #FILE exists and its set-user-ID bit is set
proc isWriteable(filename: string): bool =                     # -w FILE #FILE exists and the user has write access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IWOTH)) or
    (st.st_mode.has(S_IWUSR) and (st.st_uid == getuid())) or
    (st.st_mode.has(S_IWGRP) and (st.st_gid == getgid()))
  )
proc isExecutable(filename: string): bool =                    # -x FILE #FILE exists and the user has execute (or search) access
  var st = Stat()
  return stat(filename, st) == 0 and (
    (st.st_mode.has(S_IXOTH)) or
    (st.st_mode.has(S_IXUSR) and (st.st_uid == getuid())) or
    (st.st_mode.has(S_IXGRP) and (st.st_gid == getgid()))
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
