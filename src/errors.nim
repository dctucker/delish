type DeliError* = object of CatchableError
type ParseError* = object of DeliError
type RuntimeError* = ref object of DeliError
type SetupError* = ref object of DeliError
type InterruptError* = ref object of DeliError
