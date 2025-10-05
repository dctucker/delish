type
  DeliError*      = object of CatchableError
  RuntimeError*   = object of DeliError
  SetupError*     = object of DeliError
  InterruptError* = object of DeliError
  ParserError*    = object of DeliError
