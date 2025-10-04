import std/[sequtils, tables]
import ./common

import ../src/delitypes/functions
import ../src/delitypes/ops
import ../src/delitypes/path

suite "type functions":
  let arr123i = DK( dkArray,
    DKInt(1), DKInt(2), DKInt(3),
  )
  let arr123s = DK( dkArray,
    DKStr("1"), DKStr("2"), DKStr("3"),
  )

  test "Array.seq":
    let fn = typeFunction(dkArray, DKId("seq"))
    check fn(DKInt(3)) == arr123i
    check fn(DKInt(2), DKInt(5)) == DK( dkArray,
      DKInt(2), DKInt(3), DKInt(4), DKInt(5),
    )

  test "Array.join":
    let fn = typeFunction(dkArray, DKId("join"))
    check fn(arr123i) == DKStr("123")

  test "Integer.oct":
    let fn = typeFunction(dkInteger, DKId("oct"))
    check fn(DKInt(126)) == DKStr("0176")

  test "Integer.hex":
    let fn = typeFunction(dkInteger, DKId("hex"))
    check fn(DKInt(255)) == DKStr("0xFF")
    check fn(DKInt(63)) == DKStr("0x3F")

  test "Object.keys":
    let fn = typeFunction(dkObject, DKId("keys"))
    check fn(DeliObject([
      ("1", DKStr("1")),
      ("2", DKStr("2")),
      ("3", DKStr("3")),
    ])) == arr123s

  test "Path.stat":
    let fn = typeFunction(dkPath, DKId("stat"))
    let stat = fn(DKPath("."))
    check:
      stat.kind == dkObject
      stat.table.keys.toSeq == ["dev","ino","mode","nlink","uid","gid","rdev","size","atime","mtime","ctime","blksize","blocks","test","path"]

  test "Path.test":
    let fn = typeFunction(dkPath, DKid("test"))
    check fn(DKPath("."), DKArg("d")) == DKBool(true)
    check fn(DKPath("."), DKArg("f")) == DKBool(false)
    check fn(DKPath("tests/test_typefuncs.nim"), DKArg("f")) == DKBool(true)
    check fn(DKPath("tests/test_typefuncs.nim"), DKArg("L")) == DKBool(false)

  test "Path.pwd":
    let fn = typeFunction(dkPath, DKId("pwd"))
    check fn().kind == dkPath

  test "Path.chdir":
    let fn = typeFunction(dkPath, DKId("chdir"))
    check fn(DKPath("tests")) == DKBool(true)
    check fn(DKPath("..")) == DKBool(true)

  test "Path.list":
    let fn = typeFunction(dkPath, DKId("list"))
    let ls = fn(DKPath("."))
    check ls.kind == dkArray
    check ls.sons.len > 0
    check ls.sons[0].kind == dkPath

  test "Path.basename":
    let fn = typeFunction(dkPath, DKId("basename"))
    check fn(DKPath("tests/fixtures")) == DKPath("fixtures")

  test "Path.dirname":
    let fn = typeFunction(dkPath, DKId("dirname"))
    check fn(DKPath("tests/fixtures")) == DKPath("tests")

  test "String.split":
    let fn = typeFunction(dkString, DKId("split"))
    check arr123s == fn(DKStr("1 2 3"))
    check arr123s == fn(DKStr("1.2.3"), DKStr("."))

  test "Path.parseMode":
    var curmode = 0o777
    check parseMode("a-x"  , 0o777) == 0o666
    check parseMode("u-x"  , 0o777) == 0o677
    check parseMode("g-x"  , 0o777) == 0o767
    check parseMode("o-x"  , 0o777) == 0o776
    check parseMode("o-rwx", 0o777) == 0o770
    check parseMode("g+rwx", 0o010) == 0o070
    check parseMode("g=x"  , 0o644) == 0o614
    check parseMode("u+rx" , 0o010) == 0o510
