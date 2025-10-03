type DeliError* = object of CatchableError
type RuntimeError* = ref object of DeliError
type SetupError* = ref object of DeliError
type InterruptError* = ref object of DeliError
type ParserError* = object of DeliError
