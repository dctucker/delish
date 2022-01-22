import strutils

type
  DeliScript* = ref object
    filename*:    string
    line_numbers: seq[int]
    source*:      string

proc loadScript*(filename: string): DeliScript =
  result = DeliScript(
    filename: filename,
    line_numbers: @[0],
    source: readFile(filename)
  )

proc line_number*(script: DeliScript, pos: int): int =
  for line, offset in script.line_numbers:
    if offset > pos:
      return line - 1

iterator line_offsets(script: DeliScript): int =
  var start = 0
  let length = script.source.len()
  while start < length:
    yield start
    start = script.source.find("\n", start) + 1

proc initLineNumbers*(script: DeliScript) =
  script.line_numbers = @[0]
  for offset in script.line_offsets():
    script.line_numbers.add(offset)
  #script.debug script.line_numbers

proc getLine*(script: DeliScript, line: int): string =
  let start = script.line_numbers[line]
  if line+1 >= script.line_numbers.len:
    return script.source[start .. ^1 ]
  let endl  = script.line_numbers[line+1]
  return script.source[start .. endl-2]

