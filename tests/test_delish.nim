import unittest
import std/strutils

import ../src/delish
import ../src/delilog

suite "delish":
  test "incomplete conditional block":
    setupStrErr()
    let err = delish_main(@["tests/fixtures/errors/if.deli"])
    check:
      "missing `}`" in errlog.errors
