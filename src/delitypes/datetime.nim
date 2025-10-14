import std/times
import ./common

proc dNow(nodes: varargs[DeliValue]): DeliValue =
  argvars
  maxarg
  return DKDateTime(now())

template intAccessor(attr: untyped): untyped =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.attr.int)

proc dYear(  nodes: varargs[DeliValue]): DeliValue = intAccessor year
proc dMonth( nodes: varargs[DeliValue]): DeliValue = intAccessor month
proc dDay(   nodes: varargs[DeliValue]): DeliValue = intAccessor monthday
proc dHour(  nodes: varargs[DeliValue]): DeliValue = intAccessor hour
proc dMinute(nodes: varargs[DeliValue]): DeliValue = intAccessor minute
proc dSecond(nodes: varargs[DeliValue]): DeliValue = intAccessor second
proc dNanos( nodes: varargs[DeliValue]): DeliValue = intAccessor nanosecond

let DateTimeFunctions*: Table[string, proc(nodes: varargs[DeliValue]): DeliValue {.nimcall.} ] = {
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
