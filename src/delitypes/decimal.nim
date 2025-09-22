import ../deliast

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

proc conform(a, b: Decimal): (Decimal, Decimal) =
  if a.decimals == b.decimals:
    return (a, b)
  result[0] = a
  result[1] = b
  let decimals = max(a.decimals, b.decimals)
  result[0].fraction *= E10(decimals - a.decimals)
  result[1].fraction *= E10(decimals - b.decimals)
  result[0].decimals = decimals
  result[1].decimals = decimals

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
  if result.whole > 0 and result.fraction < 0:
    result.whole -= 1
    result.fraction += E10(result.decimals)

proc `==`*(a0, b0: Decimal): bool =
  let (a, b) = conform(a0, b0)
  return a.whole == b.whole and a.fraction == b.fraction

#proc `<=`*(o1, o2: DeliNode): bool =
#  let dw = t1.whole - t2.whole
#  return (dw < 0) or (
#    dw == 0 and t1.fraction < t2.fraction
#  )
