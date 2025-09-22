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

# 123.45
#   0.45678
proc `+`*(a, b: Decimal): Decimal =
  result.whole = a.whole + b.whole
  result.decimals = max(a.decimals, b.decimals)
  result.fraction += a.fraction * E10(result.decimals - a.decimals)
  result.fraction += b.fraction * E10(result.decimals - b.decimals)
  let overflow = ($result.fraction).len - result.decimals
  if overflow > 0:
    result.whole += overflow
    result.fraction -= E10(result.decimals)

proc `==`*(a, b: Decimal): bool =
  if a.fraction == b.fraction:
    return a.whole == b.whole and a.decimals == b.decimals
  else:
    return false

#proc `<=`*(o1, o2: DeliNode): bool =
#  let dw = t1.whole - t2.whole
#  return (dw < 0) or (
#    dw == 0 and t1.fraction < t2.fraction
#  )
