import unittest
import std/strutils
import ./common

suite "delish":
  test "incomplete conditional block":
    setupStrErr()
    let err = delish_main(@["tests/fixtures/errors/if.deli"])
    check:
      "missing `}`" in errlog.errors

  test "radix integers":
    let err = delish_main(@["tests/fixtures/test_integers.deli"])
    check err == 0

  test "decimals":
    let err = delish_main(@["tests/fixtures/test_decimals.deli"])
    check err == 0

