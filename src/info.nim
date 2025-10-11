import language/ast
import delitypes/functions
import std/[strutils,tables]

const width = 14

proc section(kind: DeliKind, name: string) =
  let funcs = typeFunctions(kind)
  if funcs.len == 0 or kind notin typeFuncUsage:
    return
  echo "\n### ", name
  echo "| Function       | Description    |"
  echo "|----------------|----------------|"
  for v in funcs:
    echo "| ", alignLeft("`." & v & "`", width), " | ", typeFuncUsage[kind][v], " |"



echo "# Functions"
section dkNone, "Built-in"
for kind in dkTypeKinds:
  section kind, kind.name
