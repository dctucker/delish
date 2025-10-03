import ./[
  delinteract,
  errors,
]
import ./language/[
  ast,
  parser,
]

var nteract = Nteract()
var node: DeliNode
nteract.filename = "parsley"
while true:
  nteract.cmdline = ""
  try:
    let input = nteract.getUserInput()
    if input == "exit":
      break
    node = quickParse(input & "\n")
    echo node.treeRepr
  except InterruptError as e:
    echo e.msg
    break
