import ../src/delitypes/casts
import ../src/delitypes/ops
import ./common

# | dest / src | String     | Identifier | Variable   | Arg        | Path       | Integer    | Boolean    | Array      | Object     | Regex      | Stream     |
# |------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|
# | String     |     -      |   id.id    | v.varName  |a.name a.val|  p.strVal  |   i.itoa   |   "true"   | a.join " " |  "[k: v]"  |  r.strVal  |   s.name   |
# | Identifier | DKIdent(s) |     -      |  DKId(v)   |DKId(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
# | Variable   |  DKVar(s)  |  DKVar(id) |     -      | Var(a.name)|     X      |     X      |     X      |     X      |     X      |     X      |     X      |
# | Arg        | -s / --str | -id / --id | --varName  |     -      |     X      |     X      |     X      |     X      |     X      |     X      |     X      |
# | Path       |    ./s     |   ./id     |     X      |  ./a.name  |     -      |    ./i     |   /bin/b   | a.join "/" |     X      |     X      | s.filename |
# | Integer    |   s.int    |     X      |     X      |     X      |     X      |     -      |   0 / 1    |   a.len    |  keys.len  |     X      |  s.intVal  |
# | Boolean    | s.len > 0  |  id.exists | ! v.isNone | ! a.isNone |  p.exists  |   i != 0   |     -      | a.len > 0  |keys.len > 0|     X      |  s.exists  |
# | Array      |  s.split   |   @[id]    |    @[v]    |    @[a]    |  p.split   |    @[i]    | @[] / @[b] |     -      | @[@[k, v]] |  r.rules   |     X      |
# | Object     |  s.parse   | [name:val] | [name:val] | [name:val] |     X      | ["int": i] |["bool": b] |[0:x,1:y...]|     -      |     X      | intval:name|
# | Regex      |  s.parse   |     X      |     X      |     X      |     X      |     X      |     X      | /(x)|(y)/  |     X      |     -      |     X      |
# | Stream     |   buffer   |     X      |     X      |     X      |     X      |   fds[i]   |     X      |   buffer   |     X      |     X      |     -      |

suite "cast":
  let ing = DKStr("Reuben")
  let ide = DKId("bread")
  let ari = DKVar("cheese")
  let arg = DKArgLong("mustard")
  let pat = DKPath("./olives")
  let num = DKInt(1)
  let boo = DKTrue
  let arr = DK(dkArray, DKStr("mayo"), DKStr("lettuce"))
  let obj = DKObject({"onions": DKStr("fresh")})
  let reg = DKRegex("[A-Za-z0-9]")
  let eam = DKStream(1)

  test "cast to boolean":
    for node in @[ing, num, arr, obj]: # these evaluate to true
      check node.toKind(dkBoolean).boolVal

    for node in @[pat]: # path probably does not exist
      check not node.toKind(dkBoolean).boolVal

    for node in @[ari, ide, arg, eam]: # depends on engine
      check node.toKind(dkBoolean).kind == dkLazy

    check:
      not DKStr("").toKind(dkBoolean).boolVal
      not DKInt(0).toKind(dkBoolean).boolVal
      not DK(dkArray).toKind(dkBoolean).boolVal
      not DK(dkObject).toKind(dkBoolean).boolVal
      DKPath(".").toKind(dkBoolean).boolVal

  test "cast to integer":
    check DKStr("123").toKind(dkInteger).intVal == 123
    check DKStr("0xff").toKind(dkInteger).intVal == 255
    check DKStr("0177").toKind(dkInteger).intVal == 127
    check boo.toKind(dkInteger).intVal == 1
    check arr.toKind(dkInteger).intVal == 2
    check obj.toKind(dkInteger).intVal == 1
    check eam.toKind(dkInteger).intVal == 1


  test "cast to same type is equal":
    check:
      ide.toKind(dkIdentifier) == ide
      ari.toKind(dkVariable)   == ari
      arg.toKind(dkArg)        == arg
      pat.toKind(dkPath)       == pat
      num.toKind(dkInteger)    == num
      boo.toKind(dkBoolean)    == boo
      arr.toKind(dkArray)      == arr
      obj.toKind(dkObject)     == obj
      reg.toKind(dkRegex)      == reg
      eam.toKind(dkStream)     == eam

  test "incompatible cast raises ValueError":
    for dk in @[dkInteger, dkRegex, dkStream]:
      expect ValueError:
        discard ide.toKind(dk)

    for dk in @[dkPath, dkInteger, dkRegex, dkStream]:
      expect ValueError:
        discard ari.toKind(dk)

    for dk in @[dkInteger, dkRegex, dkStream]:
      expect ValueError:
        discard arg.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkInteger, dkStream,
        dkObject, # TODO implement [dir: p.dirname, base: p.basename]
        dkRegex,  # TODO support globs
    ]:
      expect ValueError:
        discard pat.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkRegex]:
      expect ValueError:
        discard num.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkRegex, dkStream]:
      expect ValueError:
        discard boo.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg]:
      expect ValueError:
        discard arr.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkRegex, dkStream, dkPath]: # TODO inverse of pat->obj
      expect ValueError:
        discard obj.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkPath, dkInteger, dkBoolean, dkObject, dkStream]:
      expect ValueError:
        discard reg.toKind(dk)

    for dk in @[dkIdentifier, dkVariable, dkArg, dkArray, dkRegex]:
      expect ValueError:
        discard eam.toKind(dk)
