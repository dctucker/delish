import std/[
    strutils,
  ],
  ./[
    delinteract,
    errors,
    stacks,
  ],
  ./language/[
    ast,
    parser as parsermod,
  ]


var nteract = Nteract()
var node: DeliNode
nteract.filename = "parsley"
var parser = Parser()
var input = ""
var next = ""
while true:
  try:
    input &= nteract.getUserInput(next) & "\n"
    if input == "exit":
      break
    node = parser.quickParse(input)
    echo node.treeRepr
  except ParserError as e:
    if parser.brackets.len > 0:
      next = repeat("  ", parser.brackets.len)
      nteract.setPrompt dkBody
      continue
    else:
      echo "\27[31m", e.msg, "\27[0m"
  except InterruptError as e:
    echo e.msg
    break

  input = ""
  next = ""
  nteract.setPrompt dkScript
