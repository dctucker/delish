import unittest
import std/tables

import ../src/deliast
import ../src/delicast
import ../src/deliops

# | dest / src | String     | Identifier | Variable   | Arg        | Path       | Integer    | Boolean    | Array      | Object     | Regex      | Stream     |
# |------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|
# | String     |     -      |   id.id    | v.varName  |a.name a.val|  p.strVal  |   i.itoa   |   "true"   | a.join " " |  "[k: v]"  |  r.strVal  |   s.name   |
# | Identifier | DKIdent(s) |     -      |  DKId(v)   |DKId(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
# | Variable   |  DKVar(s)  |  DKVar(id) |     -      | Var(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
# | Arg        | -s / --str | -id / --id | --varName  |     -      |     X      |     X      |   /bin/b   |     X      |     X      |     X      |     X      |
# | Path       |    ./s     |   ./id     |     X      |  ./a.name  |     -      |    ./i     |     X      | a.join "/" |     X      |     X      | s.filename |
# | Integer    |   s.int    |     X      |     X      |     X      |     X      |     -      |   0 / 1    |   a.len    |  keys.len  |     X      |  s.intVal  |
# | Boolean    | s.len > 0  |  id.exists | ! v.isNone | ! a.isNone |  p.exists  |   i != 0   |     -      | a.len > 0  |keys.len > 0|     X      |  s.exists  |
# | Array      |  s.split   |   @[id]    |    @[v]    |    @[a]    |  p.split   |    @[i]    | @[] / @[b] |     -      | @[@[k, v]] |  r.rules   |     X      |
# | Object     |  s.parse   | [name:val] | [name:val] | [name:val] |     X      | ["int": i] |["bool": b] |[0:x,1:y...]|     -      |     X      | intval:name|
# | Regex      |  s.parse   |     X      |     X      |     X      |     X      |     X      |     X      | /(x)|(y)/  |     X      |     -      |     X      |
# | Stream     |   buffer   |     X      |     X      |     X      |     X      |   fds[i]   |     X      |   buffer   |     X      |     X      |     -      |

suite "cast":
  test "identity":
    let ing = DKStr("Reuben")
    let num = DKInt(1)
    let arg = DeliNode(kind: dkArgLong, argName: "mustard")
    let arr = DK(dkArray, DKStr("mayo"), DKStr("lettuce"))
    let boo = DKTrue
    let ide = DeliNode(kind: dkIdentifier, id: "break")
    let pat = DeliNode(kind: dkPath, strVal: "/dev/random")
    let obj = DeliNode(kind: dkObject, table: {
      "onions": DKStr("fresh"),
    }.toTable)
    let reg = DeliNode(kind: dkRegex, pattern: "[A-Za-z0-9]")
    let eam = DeliNode(kind: dkStream, intVal: 1)
    let ari = DeliNode(kind: dkVariable, varName: "cheese")

    check:
      num.toKind(dkInteger)    == num
      arg.toKind(dkArg)        == arg
      arr.toKind(dkArray)      == arr
      boo.toKind(dkBoolean)    == boo
      ide.toKind(dkIdentifier) == ide
      pat.toKind(dkPath)       == pat
      obj.toKind(dkObject)     == obj
      reg.toKind(dkRegex)      == reg
      eam.toKind(dkStream)     == eam
      ari.toKind(dkVariable)   == ari

