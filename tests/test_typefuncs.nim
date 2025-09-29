import ./common

import ../src/delitypes/functions
import ../src/delitypes/ops

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
