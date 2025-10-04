type
  DeliError* = object of CatchableError
  RuntimeError* = object of DeliError
  SetupError* = ref object of DeliError
  InterruptError* = ref object of DeliError
  ParserError* = object of DeliError
