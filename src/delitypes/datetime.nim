import std/times
import ./common

proc dNow(nodes: varargs[DeliNode]): DeliNode =
  argvars
  maxarg
  return DKDateTime(now())

template intAccessor(attr: untyped): untyped =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.attr.int)

proc dYear(  nodes: varargs[DeliNode]): DeliNode = intAccessor year
proc dMonth( nodes: varargs[DeliNode]): DeliNode = intAccessor month
proc dDay(   nodes: varargs[DeliNode]): DeliNode = intAccessor monthday
proc dHour(  nodes: varargs[DeliNode]): DeliNode = intAccessor hour
proc dMinute(nodes: varargs[DeliNode]): DeliNode = intAccessor minute
proc dSecond(nodes: varargs[DeliNode]): DeliNode = intAccessor second
proc dNanos( nodes: varargs[DeliNode]): DeliNode = intAccessor nanosecond

let DateTimeFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "now": dNow,
  "year": dYear,
  "month": dMonth,
  "day": dDay,
  "hour": dHour,
  "minute": dMinute,
  "second": dSecond,
  "nanosecond": dNanos,
}.toTable

when buildWithUsage:
  typeFuncUsage[dkDateTime] = {
    "now": "Returns the current date and time.",
    "year": "Returns an integer year.",
    "month": "Returns an integer month (1-12).",
    "day": "Returns an integer day (1-31).",
    "hour": "Returns an integer hour (0-23).",
    "minute": "Returns an integer minute (0-59).",
    "second": "Returns an integer second (0-59).",
    "nanosecond": "Returns an integer nanosecond (0-999999999).",
  }.toTable
