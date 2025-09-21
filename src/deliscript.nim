import strutils

type
  DeliScript* = ref object
    filename*:    string
    line_numbers: seq[int]
    source*:      string

proc line_number*(script: DeliScript, pos: int): int =
  for line, offset in script.line_numbers:
    if offset > pos:
      return line - 1
    result = line

proc col_number*(script: DeliScript, pos: int): int =
  let line = script.line_number(pos)
  let line_pos = script.line_numbers[line]
  return pos - line_pos

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

proc line_count*(script: DeliScript): int =
  return script.source.count('\n')

proc getLine*(script: DeliScript, line: int): string =
  if line > script.line_numbers.len:
    return "{EOF}"
  let start = script.line_numbers[line]
  if line+1 >= script.line_numbers.len:
    return script.source[start .. ^1 ]
  let endl  = script.line_numbers[line+1]
  return script.source[start .. endl-2]

proc makeScript*(name: string, source: string): DeliScript =
  result = DeliScript(
    filename: name,
    source: source,
  )
  result.initLineNumbers()

proc loadScript*(filename: string): DeliScript =
  result = makeScript(filename, readFile(filename))

