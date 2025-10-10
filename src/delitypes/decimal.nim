import ./common

const decimalPowers = [ # instead of math.pow(10, x)
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
  10000000000000000,
  100000000000000000,
  1000000000000000000,
]
template E10(x): int =
  decimalPowers[x]

proc conform(a, b: Decimal, decimals: int): (Decimal, Decimal) =
  if a.decimals == decimals and b.decimals == decimals:
    return (a, b)
  result[0] = a
  result[1] = b
  result[0].fraction *= E10(decimals - a.decimals)
  result[1].fraction *= E10(decimals - b.decimals)
  result[0].decimals = decimals
  result[1].decimals = decimals

proc conform(a, b: Decimal): (Decimal, Decimal) =
  return conform(a, b, max(a.decimals, b.decimals))

proc scaleUp(d: Decimal): int =
  return d.whole * E10(d.decimals) + d.fraction

proc scaleDown(i, decimals: int): Decimal =
  result.whole    = i div E10(decimals)
  result.fraction = i mod E10(decimals)
  result.decimals = decimals

# 123.45
#   0.45678
proc `+`*(a0, b0: Decimal): Decimal =
  let (a, b) = conform(a0, b0)
  result.whole = a.whole + b.whole
  result.fraction = a.fraction + b.fraction
  result.decimals = a.decimals
  let overflow = ($result.fraction).len - result.decimals
  if overflow > 0:
    result.whole += overflow
    result.fraction -= E10(result.decimals)

#   123    450
# -   0    5678
#   123   -1178
# = 122   
proc `-`*(a0, b0: Decimal): Decimal =
  let (a, b) = conform(a0, b0)
  result.whole = a.whole - b.whole
  result.fraction = a.fraction - b.fraction
  result.decimals = a.decimals
  let underflow = result.decimals - ($result.fraction).len
  if result.fraction < 0:
    result.whole -= 1
    result.fraction += E10(result.decimals)

#      123.45
# *    456.78
#   563894910
# = 56389.491
proc `*`*(a0, b0: Decimal): Decimal =
  let (a, b) = conform(a0, b0)
  result  = scaleDown(
    a.scaleUp * b.scaleUp,
    a.decimals + b.decimals
  )

#      2.3  ->    2300
# /    4.5  ->      45
#     51
# =    0.51
proc `/`*(a0, b0: Decimal): Decimal =
  let (a, b) = conform(a0, b0)
  let decimals = a.decimals + b.decimals + 1
  result = scaleDown(
    a.scaleUp * E10(decimals) div b.scaleUp,
    decimals
  )

#     123.45
# %     3.2
# =     1.85
proc `mod`*(a0, b0: Decimal): Decimal =
  var (a, b) = conform(a0, b0)
  result = scaleDown(
    a.scaleUp mod b.scaleUp,
    a.decimals
  )

proc `<`*(a0, b0: Decimal): bool =
  if a0.whole >= b0.whole:
    return false
  let (a, b) = conform(a0, b0)
  return a.whole < b.whole or (
    a.whole == b.whole and a.fraction < b.fraction
  )
proc `<=`*(a0, b0: Decimal): bool =
  if a0.whole > b0.whole:
    return false
  let (a, b) = conform(a0, b0)
  return a.whole < b.whole or (
    a.whole == b.whole and a.fraction <= b.fraction
  )

proc `==`*(a0, b0: Decimal): bool =
  if a0.whole != b0.whole:
    return false
  let (a, b) = conform(a0, b0)
  return a.fraction == b.fraction

proc `>=`*(a0, b0: Decimal): bool =
  if a0.whole < b0.whole:
    return false
  let (a, b) = conform(a0, b0)
  return a.whole > b.whole or (
    a.whole == b.whole and a.fraction >= b.fraction
  )

proc `>`*(a0, b0: Decimal): bool =
  if a0.whole <= b0.whole:
    return false
  let (a, b) = conform(a0, b0)
  return a.whole > b.whole or (
    a.whole == b.whole and a.fraction > b.fraction
  )

converter toFloat*(a: Decimal): float =
  return a.whole.float + a.fraction.float / E10(a.decimals).float

proc dFrac(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    DKInt(node.decVal.fraction)

proc dDenom(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    DKInt(E10(node.decVal.decimals))

proc dExponent(nodes: varargs[DeliNode]): DeliNode =
  pluralMaybe(node):
    DKInt(node.decVal.decimals)

let DecimalFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "frac": dFrac,
  "denominator": dDenom,
  "exponent": dExponent,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkDecimal] = {
    "frac": "Returns an integer of the fractional numerator.",
    "denominator": "Returns an integer of the fractional denominator.",
    "exponent": "Returns the integer number of fractional significant digits.",
  }.toTable
