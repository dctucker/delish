import language/ast
import delitypes/functions
import std/[strutils,tables]

const width = 13

echo "Built-in functions:"
var funcs = typeFunctions(dkNone)
for v in funcs:
  echo "  ", alignLeft(v, width), " ", typeFuncUsage[dkNone][v]

for kind in dkTypeKinds:
  funcs = typeFunctions(kind)
  if funcs.len == 0 or kind notin typeFuncUsage:
    continue
  echo "\n", kind.name
  for v in funcs:
    echo "  .", alignLeft(v, width), typeFuncUsage[kind][v]

