# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import deliparser
import deliengine

import os
if paramCount() < 1:
  echo "usage: delish script.deli"
  quit 2

let source = readFile(paramStr(1))
let parser = Parser(source: source)
let parsed_len = parser.parse()
parser.printStackTable()

if parsed_len != source.len():
  echo "\nERROR: Stopped parsing at pos ", parsed_len, "/", source.len()
  quit 1

let script = parser.getScript()
var engine: Engine = newEngine()

for line in engine.tick(script):
  let sline = parser.getLine(line)
  stdout.write( "\27[1;30m:", line, " \27[0;34;4m", sline, "\27[1;24m" )

